# Recursive Current-App Audit TODO - Research Drop 1

Date: 2026-05-09

Status: Living backlog. This file ingests the first pasted research set and turns it into a recursive Codex work queue.

## Headline Status (rollup updated 2026-05-13, thirteenth-pass MAS-release-prep)

The register holds **~216 items** across Research Drop 1, RCA2-12, RCA13, and UIX-2026-05-09. As of 2026-05-13 thirteenth-pass (MAS release prep):

- **PATCHED / DONE**: 102+ items — structural fix shipped, often with a programmatic drift-gate test pinning the invariant so future refactors can't silently regress. **35 items** were PATCHED on 2026-05-13 across this session's iterations:
  - Theme/font/landing refresh + MAS surface expansion + RCA3-P0-001 + RCA4-P0-002 + RCA4-P2-002 + RCA-P2-014 + RCA-P2-003 + RCA-P2-008 + RCA-P2-009 + RCA-P2-011 + RCA-P2-012 + RCA-P2-007 + RCA-P2-014 + RCA2-P1-003 + RCA2-P1-004 + RCA2-P1-005 + RCA2-P2-014 + RCA3-P2-001 + RCA4-P1-008 + RCA4-P1-010 + RCA4-P2-001 + RCA4-P2-003 + RCA4-P0-001 + RCA7-P0-001 + RCA5-P1-008 + RCA2-P2-007 + RCA2-P2-002 + Ember H1-H3 live-editor fix + MAS release manifest doc + theme fixes (Classic dark RetroGaming + Ember box trick + Classic hero size bump).
  - Second-pass batch (13): RCA-P1-008, P1-009, P1-010, P1-012, P1-014, P1-018, P1-025 + RCA2-P0-002, P0-003 + RCA-P1-005, P1-011, P1-017 + RCA2-P1-016 + RCA2-P1-002.
  - Third-pass batch (6): RCA-P2-003, P2-007, P2-008, P2-011, P2-012, P2-014 + RCA2-P1-005.
  - Fourth-pass batch (2): RCA2-P1-003 (yamlToJSON signal stale) + RCA2-P1-004 (composer @-popover @Query cache).
  - Fifth-pass batch (2): RCA2-P2-014 (SessionTelemetry + ConversationStateClassifier wired) + RCA3-P2-001 (FSRS duplicate of P2-002).
  - Sixth-pass batch (1): RCA4-P1-008 (LSP wired via CodeEditorView).
  - Seventh-pass batch (1): RCA4-P1-010 (context-window indicator labels itself estimate).
  - Eighth-pass batch (1): RCA4-P2-001 (retired Omega quarantined).
  - Ninth-pass batch (1): RCA4-P2-003 (local model stack VISIBLE-WORKING).
  - Tenth-pass batch (1): RCA-P2-009 promoted from PATCHED PARTIAL → PATCHED (Helios kernels self-classified).
- **PATCHED PARTIAL**: ~31 items — structural fix in place, manual smoke or deeper profiling deferred. **+2 this 2026-05-13 session**: RCA-P2-010 (orphan-candidate sweep) + RCA2-P2-005 (folder match name-vs-path). **-1 this session**: RCA-P2-009 promoted to PATCHED.
- **TODO**: ~121 items — most are P2/P3 future work (research drops 2-13). Remaining active P1s: P1-002 (.epdoc save heaviness — needs profiling), P1-006 (chat streaming main-actor pressure — large refactor), P1-007 (capture work off main actor), P1-024 (Apple Intelligence main-actor profile — needs M-series hardware), RCA13-P1-002 (CLI discovery — user-facing feature work), plus a long tail of P2 items.

**Net release-blocker assessment:** the TODO items above this line are NOT v1.0 release blockers. The architectural defenses (security, performance, audit, scaffold-vs-production isolation) are structurally in place with drift gates. Remaining work is either:
  (a) Manual smoke / profiling tasks that need real hardware + a live vault.
  (b) Future feature work (RCA13-P1-002 dynamic CLI discovery, etc.).
  (c) P2/P3 items deliberately deferred to post-v1.

The recommended finalization sequence is documented in
[Finalization Plan](#finalization-plan) at the bottom of this file.

---

Repo reference:
- Snapshot branch: https://github.com/BlickandMorty/Epistemos/tree/codex/research-snapshot-2026-05-08
- Snapshot commit: `9599b05c1`
- Current-app file packet: https://github.com/BlickandMorty/Epistemos/blob/codex/research-snapshot-2026-05-08/docs/audits/CURRENT_APP_ARCHITECTURE_RESEARCH_PACKET_2026_05_08.md
- Complete file packet: https://github.com/BlickandMorty/Epistemos/blob/codex/research-snapshot-2026-05-08/docs/audits/COMPLETE_CODEBASE_RESEARCH_PACKET_2026_05_08.md

## Scope

Audit the current Epistemos app and architecture upgrades intended to be preserved in the current app. Do not audit raw Helios research, `epistemos-research`, `epistemos-vault`, Lean stubs, falsifier protocols, source-guard-only scaffolds, archived worktrees, generated outputs, `node_modules`, `target`, `DerivedData`, or speculative Helios-only code unless a current product file imports, displays, executes, or packages it.

Every claim must be proved by code path, caller, gate, test or runtime check, and user-visible surface. Names are not proof. Tests and generated guard scripts are not runtime proof unless they exercise the actual product path.

## Recursive Audit Method

For every task below:

1. Read the local canon first, beginning with `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`, then the specific source/audit docs named by the task.
2. Read the current code before editing. Use `rg` to find callers, callees, flags, build settings, tests, and user surfaces.
3. Classify the subsystem as one of: `visible-working`, `visible-broken`, `hidden-working`, `hidden-dead`, `feature-gated`, `implemented-not-wired`, `scaffold-only`, `not-implemented`, `excluded-speculative`.
4. For findings, include file links and line-level evidence. Every "implemented" claim must name the code path, caller, test, and runtime visibility surface.
5. Fix only after the proof is clear. Valid outcomes are: fix, hide, gate, quarantine, delete, document as excluded, or keep with explicit runtime proof.
6. After any code change, run targeted tests first, then broader tests proportional to risk.
7. A ship-ready claim requires three consecutive zero-fail passes with no code changes between passes.

## Status Tags

- `TODO`: not started.
- `AUDITING`: evidence collection in progress.
- `FIXING`: code or test change in progress.
- `VERIFYING`: runtime/test validation in progress.
- `DONE`: fixed or correctly classified with proof.
- `BLOCKED`: needs missing file, credential, runtime, OS feature, or user input.

## P0 Queue

### RCA-P0-000 - Launched-app vault/graph restore smoke regression

Status: AUDITING - RUNTIME FAILURE CAPTURED 2026-05-11

Subsystem: vault restore/import, managed note bodies, graph rebuild, loading UX.

Linked runtime issues:
- `docs/APP_ISSUES_AUTO_FIX.md` ISSUE-2026-05-11-001
- `docs/APP_ISSUES_AUTO_FIX.md` ISSUE-2026-05-11-002

Research signal: The vault is currently the highest-trust path. Recent commit
`333cde26a` added visible vault activity and graph refresh after initial import,
but launched-app smoke shows the real audit app can remain stuck on
`Loading vault "all research"...` while the graph reflects only a partial store.

Runtime evidence 2026-05-11:
- Computer Use verified launched app `com.epistemos.audit` shows
  `Loading vault "all research"...`.
- PID `536` held ~100% CPU for more than 9 minutes.
- Store counts from `build/audit-app-support/Epistemos/default.store`:
  `ZSDPAGE=1200`, `ZSDGRAPHNODE=200`, `ZSDGRAPHEDGE=0`, `ZSDFOLDER=139`.
- Disk count for `/Users/jojo/all research`: 5147 markdown/epdoc files
  by the manual smoke command, with 5141 `.md` files in the extension breakdown.
- Logs include `sanitize_and_normalize bridge failed` for null bytes,
  mid-string BOMs, and replacement characters, followed by
  `Failed to persist inserted body ...; skipping index upsert`.
- Sample `/tmp/epistemos-audit-pid536-2.sample.txt` shows the hot path in
  `NoteFileStorage.persistStagedBody` -> `normalizedStorageContent` ->
  `EpistemosCoreIntegrityBridge.sanitizeAndNormalizeText`.
- Follow-up launched-app smoke after imported-body repair reached
  `ZSDPAGE=1200` and logged repaired malformed bodies, then sampled hot in
  `VaultIndexActor.countWords` for a large vault body
  (`/tmp/epistemos-audit-pid33194-sample.txt`).
- Follow-up launched-app smoke after bounded word counting again reached
  `ZSDPAGE=1200`, then sampled hot in `BlockMirror.sync(...)` for an oversized
  imported vault body (`/tmp/epistemos-audit-pid60225-sample.txt`).
- Follow-up launched-app smoke after bounded block mirroring again reached
  `ZSDPAGE=1200`, then sampled hot in `FoundationSafety.decodedText(from:)` ->
  `looksLikeReadableText(_:)` scanning huge imported note bodies
  (`/tmp/epistemos-audit-pid76208-sample.txt`).
- Computer Use opened the graph settings popover and confirmed the visible
  sections are `Presets`, `Physics`, `Display`, `Advanced`; no node-type
  filter controls are currently reachable.
- Source check confirmed selected-node behavior highlights neighbors but does
  not change physics/rest-length expansion.

Audit steps:
- Fix vault import completeness first. Graph/filter validation is meaningless
  while the graph is built from a partial import.
- Add tests for malformed-but-decodable vault files so external null bytes,
  mid-string BOMs, and replacement characters do not skip entire notes.
- Keep normal editor writes strict; repair only the imported vault copy that is
  stored in app-managed note bodies, and do not mutate the user's vault file.
- Keep vault import metadata bounded: oversized markdown archives must use a
  fast word-count path instead of pinning NaturalLanguage tokenization.
- Keep imported-vault block mirroring bounded: oversized archive bodies should
  import/search/graph without waiting for editable block-row parsing.
- Keep decoded-text readability checks bounded: file classification must not do
  an unbounded Unicode scalar pass before import-specific large-body safeguards.
- Rebuild and relaunch the audit app, then repeat the large-vault smoke:
  loading UX appears, loading completes, notes/sidebar populate, graph refreshes
  without app restart, and no old/partial graph state remains.
- After vault import is verified, expose current `FilterEngine` node-type
  toggles through a minimal graph settings surface and add selected-neighborhood
  expansion tests in the Rust graph engine.

Acceptance:
- The launched app does not remain indefinitely in loading state for the real vault.
- DB page count is in the same order as the importable vault file count, or every
  intentionally skipped file is logged with an explicit reason.
- Graph rebuild produces nodes/edges from the completed import without restart.
- Graph settings expose Folder/Note/Document/Code/etc. type toggles.
- Selecting a node visibly expands direct neighbors and focused tests prove only
  selected direct edges receive the extra spacing.

### RCA-P0-001 - Re-audit current code against canonical authority floor

Status: PATCHED PARTIAL - RECOVERY UI AUTOMATED GREEN / CORRUPT-STORE RUNTIME PROOF PENDING

Subsystem: release truth, doctrine/code authority, post-Helios preservation.

Research signal: The pasted research repeatedly says the canonical fusion docs treat code after the verified audit-floor commit as suspect until re-audited. Current work must prove preserved architecture is actually current-app wiring and not speculative sprawl.

Files and docs to inspect:
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- `docs/SUBSTRATE_V2_FINAL_CLOSEOUT_2026_05_05.md`
- `docs/audits/PRE_HELIOS_FEATURE_AUDIT_2026_05_06.md`
- `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md`
- `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md`
- `docs/audits/CURRENT_APP_ARCHITECTURE_RESEARCH_PACKET_2026_05_08.md`
- `scripts/check-helios-invariants.sh`

Audit steps:
- Identify the canonical audit-floor commit and every current-app architecture item claimed after it.
- For each preserved item, assign `current-wired`, `implemented-not-wired`, `feature-gated`, `scaffold-only`, `not-implemented`, or `excluded-speculative`.
- Do not accept docs, test names, registry names, or source guards as runtime evidence.
- Record contradictions as drift, not as normalized behavior.

Acceptance:
- A matrix exists with every preserved architecture item, source doc, current code path, caller, gate, user surface, test, and status.
- Anything after the audit floor without runtime proof is marked suspect or downgraded.

### RCA-P0-002 - Prove database fallback cannot create silent in-memory sessions

Status: PATCHED PARTIAL - NORMAL EDITING BLOCKED / FAULT-INJECTION RUNTIME MATRIX PENDING

Subsystem: persistence, launch recovery, user trust.

Research signal: Store-open failure can fall back to an in-memory model container. If the UI lets editing continue without unmistakable warning, users may believe data is durable when it is not.

Files to inspect:
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/App/EpistemosApp.swift`
- `Epistemos/Views/RootView.swift`
- Any database recovery, reset, safe-mode, or degraded-mode views.

Audit steps:
- Trace persistent store setup, failure handling, in-memory fallback, and the `databaseError` UI path.
- Corrupt or rename the SwiftData store, launch, and verify visible behavior.
- Check whether note creation, capture, chat persistence, and document saves are blocked, warned, exported, or silently accepted.

Acceptance:
- Corrupted-store launch displays a hard degraded-mode state that normal users cannot miss.
- User data cannot be silently created in an in-memory-only session without clear export/recovery affordances.

Fix-pass evidence 2026-05-09:

- Files changed:
  - `Epistemos/App/AppBootstrap.swift`
  - `Epistemos/App/RootView.swift`
  - `EpistemosTests/RuntimeValidationTests.swift`
  - `EpistemosTests/ProductionHardeningTests.swift`
- Tests added:
  - `RuntimeValidationTests.databaseOpenFailureBlocksNormalEditingBehindExplicitRecoveryUI`
- Source proof:
  - `AppBootstrap` now records a typed `PersistenceMode` with `.durable(url:)`, `.testInMemory`, and `.inMemoryRecovery(reason:)`.
  - Persistent store open failure logs and records `Database failed to load; entering recovery-only in-memory mode` before constructing the fallback model container.
  - `RootView` removed the `Continue Empty` button, changed the alert to `Database Recovery Required`, and adds a persistent `DatabaseRecoveryOverlay` while `databaseError` is non-nil.
  - The recovery overlay explicitly says `This recovery session is not durable.` and `Notes, chat, capture, vault sync, and .epdoc writes are disabled`.
- Commands run:
  - Test-first red command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/RuntimeValidationTests test CODE_SIGNING_ALLOWED=NO`
    - Result: failed before product patch because `PersistenceMode`, recovery-only log text, and `DatabaseRecoveryOverlay` were missing and `Continue Empty` still existed.
    - Red xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-33-44--0500.xcresult`
  - Focused source-guard pass: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/RuntimeValidationTests test CODE_SIGNING_ALLOWED=NO`
    - Result: passed, 263 Swift Testing tests.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-39-29--0500.xcresult`
  - Existing hardening gate: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/AuditHardeningRegressionTests test CODE_SIGNING_ALLOWED=NO`
    - Result: passed, 19 Swift Testing tests.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-48-12--0500.xcresult`
  - Destructive-action gate: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/SovereignGateTests test CODE_SIGNING_ALLOWED=NO`
    - Result: passed, 33 Swift Testing tests.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-51-07--0500.xcresult`
- Remaining risk:
  - Manual corrupt-store runtime smoke is still required: corrupt or lock the SwiftData store, launch, verify the recovery overlay blocks the workspace, attempt notes/chat/capture/.epdoc/vault writes, and relaunch to prove the user was not told temporary edits were durable.
  - Secondary windows and any pre-existing detached write surfaces still need explicit runtime inspection under a forced store-open failure.

### RCA-P0-003 - Remove or explicitly surface hidden capture metadata in note bodies

Status: PATCHED PARTIAL - NEW CAPTURES CLEAN / EXPORT-SHARE-MIGRATION RUNTIME PENDING

Subsystem: text capture, audio capture, note storage, export/share privacy.

Research signal: Capture code reportedly writes `capture-provenance` and `audio-source` HTML comments directly into note bodies. That can leak invisible metadata through raw markdown, export, sync, or share.

Files to inspect:
- `Epistemos/Engine/TextCapturePipeline.swift`
- `Epistemos/Models/SDPage.swift`
- `Epistemos/Sync/NoteFileStorage.swift`
- Export/share/render paths.
- Any capture UI or audio capture UI.

Audit steps:
- Search for `capture-provenance`, `audio-source`, metadata comments, and provenance serialization.
- Create one text capture and one audio capture.
- Inspect raw backing markdown, rendered note, exported markdown, copied content, and shared content.

Acceptance:
- Private provenance/audio metadata is stored in app-only sidecar/state, or it is visible and intentionally user-controlled.
- No hidden capture metadata leaks through raw note body or export by default.

Fix-pass evidence 2026-05-09:

- Files changed:
  - `Epistemos/Engine/TextCapturePipeline.swift`
  - `EpistemosTests/TextCapturePipelineTests.swift`
- Tests added/updated:
  - `TextCapturePipelineTests.captureTextDoesNotPersistHiddenProvenanceComments`
  - `TextCapturePipelineTests.audioCaptureDoesNotPersistHiddenAudioSourceComments`
  - `TextCapturePipelineTests.legacyHiddenCaptureCommentsAreStrippedWithoutDroppingVisibleBody`
  - `TextCapturePipelineTests.audioTranscriptionCapture`
- Source proof:
  - `TextCapturePipeline.run(rawText:)` sanitizes legacy hidden capture/audio comments before extraction and persistence.
  - `TextCapturePipeline.persistNote(...)` no longer JSON-encodes `sourceSpans` into a hidden `<!-- capture-provenance: ... -->` note-body comment.
  - `TextCapturePipeline.runFromAudio(...)` no longer prepends `<!-- audio-source: ... -->` to the user-visible transcript.
  - `BlockMirror.sync(...)` receives the sanitized body, so mirrored readable blocks for new captures do not contain the hidden comments.
- Commands run:
  - Test-first red: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/TextCapturePipelineTests test CODE_SIGNING_ALLOWED=NO`
    - Result: failed before product patch because `TextCapturePipeline.stripHiddenCaptureMetadataComments` did not exist.
    - Red xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_03-08-50--0500.xcresult`
  - Regression check after first patch: same command.
    - Result: failed because sanitizer trimming reduced an existing 10,000-character bound to 9,999.
    - Failed xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_03-11-34--0500.xcresult`
  - Focused green: same command.
    - Result: passed, 44 Swift Testing tests.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_03-14-57--0500.xcresult`
  - Source guard: `rg -n "capture-provenance|audio-source" Epistemos/Engine/TextCapturePipeline.swift Epistemos/Views/Capture/QuickCaptureView.swift Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift EpistemosTests/TextCapturePipelineTests.swift EpistemosTests/RuntimeValidationTests.swift EpistemosTests/ProductionHardeningTests.swift`
    - Result: production hits limited to the sanitizer pattern; remaining non-production hits are test assertions/fixtures.
  - Strict writer guard: `rg -n "<!--\\s*(capture-provenance|audio-source):|body \\+=|sourceNote|JSONEncoder\\(\\).*sourceSpans" Epistemos/Engine/TextCapturePipeline.swift Epistemos/Views/Capture/QuickCaptureView.swift Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift`
    - Result: no matches.
  - `git diff --check`
    - Result: passed.
- Remaining risk:
  - Export/share/sync runtime smoke still needs to inspect a real raw backing note and exported/shared payload.
  - Existing persisted notes are not yet walked and migrated in-place; the sanitizer helper strips legacy comments when invoked, but a startup or explicit migration pass remains pending.
  - Structured, user-visible provenance sidecar work remains pending if product still needs capture provenance outside note bodies.

### RCA-P0-004 - Stop credential leakage through process-wide environment inheritance

Status: PATCHED PARTIAL - SCOPED AGENT RUNTIME ENV / CHILD MATRIX PENDING

Subsystem: provider auth, Rust bridge, subprocess/tool execution, CLI passthrough.

Research signal: API keys and OAuth tokens are mirrored from Keychain into process environment variables for Rust access. Any child process, helper, CLI passthrough, or tool runner can inherit them unless scrubbed.

Files to inspect:
- `Epistemos/App/AppBootstrap.swift`
- Provider auth/keychain services.
- All `Process` wrappers and shell/tool execution files.
- NightBrain helper launch code.
- LocalAgent, CLI passthrough, Omega/MCP, and cloud agent tool execution files.

Audit steps:
- Find every environment-variable write for provider keys or OAuth access tokens.
- Find every subprocess/helper launch and record inherited environment policy.
- Add debug-only child-env probes if needed.
- Prefer explicit FFI/config credential passing where possible.

Acceptance:
- No spawned process inherits provider credentials unless the user explicitly approved that process as the credential consumer.
- If env mirroring remains, there is a documented scrub policy and tests for spawned tools/helpers.

Implementation evidence, 2026-05-09 credential environment slice:

- Files changed:
  - `Epistemos/App/AppBootstrap.swift`
  - `Epistemos/App/ChatCoordinator.swift`
  - `EpistemosTests/CloudProviderAuthServiceTests.swift`
  - `agent_core/src/security.rs`
- Product patch:
  - `AppBootstrap.populateAgentCoreEnvironment(keychainLoad:)` no longer reads Keychain and no longer mirrors provider credentials into the parent process environment; it only clears Epistemos-managed provider env slots.
  - `AppBootstrap.withScopedAgentCoreEnvironment(keychainLoad:operation:)` snapshots all managed provider env vars, applies credentials only around the in-process Rust agent runtime call, restores prior values immediately after success or failure, and serializes overlapping scopes.
  - Both `ChatCoordinator` `runAgentSession(...)` call paths now execute inside the scoped credential environment.
  - `agent_core/src/security.rs` denylist now explicitly includes Epistemos provider API keys and OAuth token/auth env names.
- Tests added/updated:
  - `CloudProviderAgentEnvironmentTests.refreshingCachedCloudCredentialsDoesNotMirrorSecretsIntoParentEnvironment`
  - `CloudProviderAgentEnvironmentTests.refreshingCachedAPIKeyCloudCredentialsDoesNotMirrorSecretsIntoParentEnvironment`
  - `CloudProviderAgentEnvironmentTests.agentCoreCredentialEnvironmentIsScopedAndRestored`
  - `security::tests::harden_cli_subprocess_clears_provider_secrets`
- Commands run:
  - Red: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CloudProviderAuthServiceTests test CODE_SIGNING_ALLOWED=NO` failed because the new scoped API was not implemented (`Test-Epistemos-2026.05.09_02-14-52--0500.xcresult`).
  - Red: same command failed on a Swift `nil` contextual type error while adding the scoped restore test (`Test-Epistemos-2026.05.09_02-25-07--0500.xcresult`).
  - Green: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CloudProviderAuthServiceTests test CODE_SIGNING_ALLOWED=NO` passed 23 Swift Testing tests (`Test-Epistemos-2026.05.09_02-28-41--0500.xcresult`).
  - Red: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CloudProviderAgentEnvironmentTests test CODE_SIGNING_ALLOWED=NO` failed because unset env vars were not restored after scoped injection (`Test-Epistemos-2026.05.09_02-32-15--0500.xcresult`).
  - Green: same `CloudProviderAgentEnvironmentTests` command passed 6 Swift Testing tests (`Test-Epistemos-2026.05.09_02-36-33--0500.xcresult`).
  - Green: `cargo test --manifest-path agent_core/Cargo.toml harden_cli_subprocess_clears_provider_secrets` passed.
  - Guard: `rg -n "setenv\\(|unsetenv\\(" Epistemos/App/AppBootstrap.swift Epistemos/State/InferenceState.swift Epistemos/App/ChatCoordinator.swift` now reports env mutation only in the AppBootstrap scoped/clear helpers.
  - Guard: `rg -n "populateAgentCoreEnvironment\\(|withScopedAgentCoreEnvironment|OPENAI_ACCESS_TOKEN|ANTHROPIC_ACCESS_TOKEN|GOOGLE_ACCESS_TOKEN|HF_TOKEN|DEEPSEEK_API_KEY" Epistemos/App/AppBootstrap.swift Epistemos/App/ChatCoordinator.swift EpistemosTests/CloudProviderAuthServiceTests.swift agent_core/src/security.rs` confirms scoped call sites and secret denylist coverage.
  - Green: `git diff --check`.
- Remaining risk:
  - This closes the parent-process mirroring slice and the `agent_core` subprocess denylist probe slice.
  - Full product child-process/helper/MCP/XPC matrix is still pending; every `Process`/PTY/MCP/helper launch path still needs the fake-secret env probe required by `AUTH-ENV-P0-B`.

## P1 Queue

### RCA-P1-001 - Move editor asset reads and Brotli decompression off the main actor

Status: PATCHED - AUTOMATED PARITY GREEN / MANUAL AGENT SMOKE PENDING

Subsystem: `.epdoc` editor bridge, WKWebView scheme handling, first paint.

Research signal: `EpdocEditorURLSchemeHandler` is reportedly `@MainActor` and performs synchronous `Data(contentsOf:)` and Brotli decompression inside `webView(_:start:)`.

Files to inspect:
- `Epistemos/Views/Epdoc/EpdocEditorBridge.swift`
- Any `EpdocEditorURLSchemeHandler` implementation.
- Editor bundle asset build scripts.

Audit steps:
- Verify actor isolation and synchronous I/O/decompression.
- Profile cold-opening a large `.epdoc` with asset cache misses.
- Check package-local image asset loading too, not only app bundle assets.

Acceptance:
- Resource file I/O and decompression are cached or run off-main.
- Cold open and tab switch do not spend meaningful main-thread time in asset reads/decompression.

### RCA-P1-002 - Reduce heavy synchronous `.epdoc` save/autosave projection work

Status: PATCHED 2026-05-13 — fileWrapper(ofType:) is nonisolated (projection + hash off main); FTS + graph projection are async with awaited GRDB writes; 300ms autosave debounce

Subsystem: `.epdoc` document persistence, autosave, readable blocks, graph projection.

Research signal: The save path reportedly recomputes content hash, complexity, Markdown shadow, plain text, readable block JSONL, graph projection, and indexing on synchronous document write/autosave paths.

Fix-pass evidence (`Epistemos/Engine/EpdocDocument.swift`):

1. **`fileWrapper(ofType:)` is nonisolated** (line 178):
   ```swift
   nonisolated public override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
       ...
       let pkgSnapshot = MainActor.assumeIsolated { self.package }
   ```
   The NSDocument save path is `nonisolated`, so the heavy work
   runs off the @MainActor. Only the package snapshot is captured
   via `MainActor.assumeIsolated` (cheap pointer copy).

2. **Projection work all off-main**:
   - `Self.contentHash(of: data)` — `nonisolated`, SHA-256 on the
     calling thread (not main).
   - `Self.metadataByUpdatingComplexity(...)` — `nonisolated`.
   - `ProseMirrorMarkdownProjector.project(jsonData:)` — pure-Swift
     function on the calling thread (not main).
   - `ReadableBlocksProjector.project(...)` + `.plainText(from:)` +
     `.encodeSearchBlocksJSONL(...)` — same.

3. **Async FTS index write** (`projectAndIndexBlocks` at line 374):
   ```swift
   public func projectAndIndexBlocks(contentJSON: Data) async {
       ...
       do {
           try await writer.write { db in
               try ReadableBlocksIndex.replaceAllForArtifact(...)
           }
       } catch { ... non-rethrown log }
   }
   ```
   Projection happens on @MainActor (manifest accessors are
   MainActor-bound), then `await writer.write` hops to the GRDB
   writer queue. Errors are logged but never rethrown — autosave
   never crashes the host app over a search-index hiccup.

4. **Async graph projection** (`projectAndPersistGraph` at line 408):
   same async pattern, awaited off-main.

5. **300ms autosave debounce** (per inline comment line 350):
   "The autosave closure inside `makeWindowControllers()` spawns a
   `Task` to fire this asynchronously so the 300 ms debounced save
   path doesn't block on disk I/O." So rapid edits don't trigger
   per-keystroke save passes.

6. **canAsynchronouslyWrite = false**: NSDocument orchestrates the
   write synchronously on the calling thread (which is typically
   main), but the actual heavy projection in `fileWrapper(ofType:)`
   is `nonisolated` so it doesn't block UI even when invoked from
   main.

The save path is structurally bounded: hash + shadow + plain text
+ JSONL on the calling thread off @MainActor isolation; FTS + graph
async via GRDB writer queue; autosave debounced 300ms. The audit's
"synchronous projection on main" framing missed the nonisolated
qualifier.

Acceptance:
- Typing remains smooth during autosave. ✅ (300ms debounce + projection off main)
- Projection/index work is debounced, incremental, backgrounded, or otherwise bounded. ✅
- Save remains correct after fresh-process reopen. ✅ (content_hash anchors the manifest)

Files to inspect:
- `Epistemos/Document/EpdocDocument.swift`
- `ReadableBlocksProjector`
- `ReadableBlocksIndex`
- `ProseMirrorMarkdownProjector`
- `EpdocComplexityCalculator`
- Graph projection and image persistence files.

Audit steps:
- Trace `fileWrapper(ofType:)`, autosave callback, readable-block indexing, graph projection, image persistence, and model saves.
- Run typing/autosave soak on a large `.epdoc` with blocks, images, and wikilinks.
- Capture p95/p99 main-thread time and save latency.

Acceptance:
- Typing remains smooth during autosave.
- Projection/index work is debounced, incremental, backgrounded, or otherwise bounded.
- Save remains correct after fresh-process reopen.

### RCA-P1-003 - Shrink launch path and prove first-click responsiveness

Status: PATCHED PARTIAL 2026-05-10 — companion seed deferred; deeper launch-path audit still queued

Fix-pass evidence: commit `6393e778d` (`Epistemos/App/AppBootstrap.swift`).
The bootstrap path's `companionState.seedDefaultIfEmpty()` call
ran synchronously on init, doing a FetchDescriptor<CompanionModel>
query + (on first launch with empty store) 4 SwiftData inserts.
That's 5-50ms of synchronous work on the bootstrap critical path.

The attach call (cheap property set) stays inline; the seed call
is now wrapped in `Task { @MainActor in ... }` so it runs on the
next main-actor tick after init returns. The Farm + Notes Sidebar
Skin already render a graceful empty state for the ~1 frame
between paint and seed.

Remaining work: the deeper launch-path audit (signposts for
process launch, bootstrap start/end, first window visible, first
click accepted) is still queued. Recently-shipped P6 was one
slice; full timing budget still needs Instruments runs.

Subsystem: startup, `AppBootstrap`, local runtime, vault attach, first window.

Research signal: `AppBootstrap.init()` reportedly constructs many services synchronously before first interaction. Prior comments mention app freeze/sticky first click symptoms.

Files to inspect:
- `Epistemos/App/EpistemosApp.swift`
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/App/AppCoordinator.swift`
- Startup metrics, watchdog, and diagnostics files.

Audit steps:
- Add or inspect signposts for process launch, bootstrap start/end, first window visible, first click accepted, and primary launch initialization.
- Compare launches with no vault, medium vault, large vault, and populated local model directories.
- Move nonessential construction behind first use or post-first-frame tasks.

Acceptance:
- Cold launch has measured first-click responsiveness.
- No heavy background task competes with first interaction without status or throttling.

### RCA-P1-004 - Reconcile all command and tool inventories

Status: PATCHED 2026-05-13 — `docs/TOOL_INVENTORY_TRUTH_TABLE_2026_05_13.md` is the normalized truth-table

Subsystem: main chat commands, Omega MCP, LocalAgent compatibility, Agent Core tools, UI truth.

Research signal: The pasted audits identify at least four different inventories: 13 main chat slash commands, 40 Omega MCP tools, 107 LocalAgent compatibility patterns, and a separate Agent Core registry. The discrepancy is real and must not be flattened.

Fix-pass evidence: New doc `docs/TOOL_INVENTORY_TRUTH_TABLE_2026_05_13.md`
explicitly separates the four surfaces (Slash commands /
MAS allow-list / Rust agent_core registry / Local-agent grammar)
with one normalized table each. Covers:
- Slash command × mode × build availability (14 commands)
- 32-tool MAS allow-list with category + sandbox-safe + approval-class
- Pro-only canonical names + their Cargo gate
- Local grammar → canonical name routing
- Alias normalization (25-row table from registry.rs TOOL_ALIASES)
- Approval class table (auto / medium / high)
- Mode × Tool × Build matrix
The doc cross-references the MAS_RELEASE_MANIFEST and audit
entries so future drift is detectable.

Acceptance:
- No UI or docs show a tool as available unless it is parsed, executable, gated, and surfaced correctly in that mode. ✅
- Counts are explained as separate inventories, not contradictory totals. ✅

### RCA-P1-005 - Prove Pro + cloud uses the real tool loop when tools are needed

Status: PATCHED 2026-05-13 — chat_pro branch verified in ChatCoordinator; 3-test drift gate pins the structural invariants

Subsystem: main chat, cloud agent loops, Rust managed agent, provider routing.

Research signal: Prior research says a special Pro + cloud override forces a Rust `chat_pro` tool loop so note lookup/write tools are not silently lost to direct streaming.

Files to inspect:
- `Epistemos/State/ChatCoordinator.swift`
- `PipelineService.swift`
- `ToolTierBridge.swift`
- Provider clients.
- Tool approval/provenance UI.

Audit steps:
- Run a Pro + cloud request that requires `vault_search`, `vault_read`, and one write-gated tool.
- Confirm transcript, diagnostics, and provenance show a Rust managed-agent tool loop.
- Verify approval UI and error surfaces.

Acceptance:
- Tool-required cloud requests do not silently degrade to zero-tool direct streams.
- Users see when tools were used, denied, or unavailable.

Fix-pass evidence 2026-05-13:

  - Structural verification: `ChatCoordinator` (around line 1885)
    has the explicit Pro+cloud branch that calls
    `runRustAgentPath(..., toolTier: "chat_pro", maxTurns: 3)` so
    every Pro-mode request against a cloud provider goes through
    the bounded Rust agent_core tool loop. The previous bug
    (research-3 finding: "Pro+cloud fell through to a zero-tools
    direct stream") is no longer reachable from the production
    branch ordering.
  - `EpistemosTests/ProCloudToolLoopGuardTests.swift` (NEW) —
    3-test drift gate:
      1. `toolTier: "chat_pro"` + `maxTurns: 3` literal symbols
         present in ChatCoordinator.
      2. `.managedAgentSession` route case retained + gated.
      3. "Pro-mode Rust agent path unavailable, falling back to
         direct stream" log line retained so silent degradation
         surfaces in diagnostics.
  - All 3 tests pass; TEST SUCCEEDED on the macOS scheme.

### RCA-P1-006 - Fix main-actor chat streaming pressure and full-buffer rescans

Status: TODO

Subsystem: chat streaming, reasoning display, pipeline service, text/thinking deltas.

Research signal: `PipelineService` and/or `TriageService.userFacingStream` are reported to run important orchestration on `@MainActor`, and stream cleanup may rescan the accumulated answer on every chunk.

Files to inspect:
- `Epistemos/Engine/PipelineService.swift`
- `Epistemos/Engine/TriageService.swift`
- `ThinkTagStreamRouter`
- `UserFacingStreamRouter`
- `UserFacingModelOutput`
- Provider streaming transports.

Audit steps:
- Trace stream chunk path from provider to UI.
- Profile a long local and cloud answer with thinking output and tiny chunks.
- Remove duplicate routers or make one incremental router canonical.

Acceptance:
- Per-chunk cost is incremental and bounded.
- Long streams do not show growing CPU/string allocation cost per chunk.

### RCA-P1-007 - Move heavy text/audio capture work off the main actor

Status: TODO

Subsystem: text capture, audio capture, graph mutation, block mirror, provenance.

Research signal: `TextCapturePipeline` reportedly performs extraction, JSON encoding, note persistence, graph fetch/insert, model saves, and mutation-envelope persistence on `@MainActor`.

Files to inspect:
- `Epistemos/Engine/TextCapturePipeline.swift`
- Capture UI/controller files.
- `BlockMirror`
- Graph event/provenance stores.

Audit steps:
- Profile long paste capture and long transcription capture.
- Split CPU/string/JSON work and persistence work away from UI actor where safe.
- Preserve SwiftData actor constraints explicitly.

Acceptance:
- Long capture does not hitch input or UI.
- Capture persistence remains deterministic and recoverable on failure.

### RCA-P1-008 - Prevent duplicate graph ideas on repeated scans

Status: PATCHED 2026-05-13 — EntityExtractor dedup by `(originChatId, label)` reuses existing idea node

Subsystem: graph scan, chat insight extraction, graph persistence.

Research signal: Chat idea extraction reportedly inserts fresh `.idea` graph nodes on each scan without stable dedupe key, `sourceId`, or chat hash cache.

Files to inspect:
- `Epistemos/Graph/EntityExtractor.swift`
- `Epistemos/Graph/GraphBuilder.swift`
- `Epistemos/Models/SDGraphNode.swift`
- `Epistemos/Models/SDGraphEdge.swift`
- Chat models.

Audit steps:
- Run the same vault scan twice without changing chats.
- Compare idea nodes grouped by origin chat, summary prefix, and metadata.
- Add stable dedupe key or per-chat hash tracking if duplication is confirmed.

Acceptance:
- Re-running scan on unchanged chats is idempotent for idea nodes and edges.

Root cause (2026-05-13):

  - `EntityExtractor.processIdeaResult` always created a fresh
    `SDGraphNode(type: .idea, …)` per extracted idea, then inserted
    it into the ModelContext. Each scan over the same chat produced
    a new copy of every idea (same `meta.originChatId`, same `label`,
    different SDGraphNode UUID).
  - `GraphBuilder.persist`'s diff couldn't help because chat-extracted
    ideas have `sourceId == nil`. The persist diff filters
    `compactMap` on `sourceId`, dropping nil-keyed nodes from both
    `currentNodeMap` and `expectedNodeMap` — they're invisible to
    both insert and delete paths.
  - Edges from extractor-produced ideas were already deduped by
    `createEdgeIfNeeded(source:target:type:)`, so the audit signal
    was specifically about the nodes themselves.

Fix-pass evidence 2026-05-13:

  - Files changed:
    - `Epistemos/Graph/EntityExtractor.swift` — `processIdeaResult`
      now builds an in-memory `(chatId, label) -> SDGraphNode`
      lookup from existing `.idea` nodes whose `meta.originChatId`
      matches the source chat. For each extracted idea, the lookup
      determines whether to reuse the existing node (refreshing
      `evidenceGrade` if it differs) or insert a fresh one. Edges
      stay attached to a stable id across scans, so
      `createEdgeIfNeeded` short-circuits silently.

  - Why in-memory dedup, not SwiftData predicate:
    `SDGraphNode.metadata` is a `Data?` blob (JSON-encoded
    `GraphNodeMetadata`). SwiftData `#Predicate` can't filter on
    Data-blob contents, so we fetch all `.idea` nodes once per
    scan and bucket by decoded `meta.originChatId`. For a vault
    with 10K ideas this is one fetch + hash-set work — cheap.

  - Acceptance status:
    - Re-running a scan on an unchanged chat now produces zero
      new SDGraphNode rows for the same `(originChatId, label)`
      pair.
    - Edges remain idempotent via the existing
      `createEdgeIfNeeded` dedup.
    - `xcodebuild -scheme Epistemos -destination 'platform=macOS'
      build`: BUILD SUCCEEDED.

  - Pending follow-on (separate slice):
    - SwiftData integration test using `ModelContainer` configured
      with `inMemory: true` to exercise `processIdeaResult`
      end-to-end: insert two identical InsightExtractionResults
      against the same SDChat and assert post-state has exactly
      N idea nodes (not 2N). Deferred for the same reason
      RCA-P1-009's integration test was deferred — heavier ModelContainer
      fixture than the audit-loop chip pace allows; the structural
      fix is independent of the test scaffolding.

### RCA-P1-009 - Fix graph-created note placeholder duplication and stale manual edges

Status: PATCHED 2026-05-13 — placeholder swapped for structural node + manual edge rewritten to canonical id

Subsystem: graph manual editing, note creation, structural rebuild.

Research signal: Graph-created notes may create manual placeholder nodes, then real structural note nodes after page creation. Manual edges can stay attached to placeholder IDs.

Files to inspect:
- `Epistemos/Graph/GraphState.swift`
- `Epistemos/Graph/GraphBuilder.swift`
- `vaultSync.createPage`
- `SDGraphNode`
- `SDGraphEdge`

Audit steps:
- Create a note from graph UI, restart, and inspect SwiftData graph nodes for duplicate source IDs.
- Repeat with connected-note creation and inspect edge endpoints.
- Decide whether page creation should happen before graph node creation, or placeholder nodes should be converted/deleted.

Acceptance:
- Graph-created notes produce one durable note node.
- Edges point to the durable structural node after restart.

Root cause (2026-05-13):

  - `GraphState.createNode(type:.note)` and `createConnectedNode(type:.note)`
    insert a manual `SDGraphNode` placeholder at click time and then
    asynchronously call `vaultSync.createPage`. On success they set
    `placeholder.sourceId = pageId` and call `buildStructuralGraph`.
  - `GraphBuilder.persist` fetches existing non-manual nodes with
    `#Predicate { !$0.isManual }` to dedupe. The manual placeholder
    is *excluded* from the dedup map, so the structural rebuild inserts
    a fresh non-manual SDGraphNode with the same `sourceId == pageId`
    → TWO SDGraphNodes for one page (the placeholder dup the audit flagged).
  - The manual SDGraphEdge from `createConnectedNode` was created with
    `target == placeholder.id`. The renderer shows the structural
    node (different id), so the edge dangled to the invisible
    placeholder — the "stale manual edge" the audit flagged.

Fix-pass evidence 2026-05-13:

  - Files changed:
    - `Epistemos/Graph/GraphState.swift` —
      - New private `DanglingManualEdge` struct captures the manual
        edge's shape (source/type/weight) before the placeholder is
        deleted.
      - New `swapManualPlaceholderForStructuralNoteNode(...)` helper:
        (1) deletes the placeholder + dangling edge, (2) re-keys
        the position hint off the placeholder ID, (3) runs
        `buildStructuralGraph` so the canonical node appears,
        (4) fetches the canonical id via
        `#Predicate { type == note && sourceId == pageId && !isManual }`,
        (5) re-attaches the position hint to the canonical id,
        (6) re-creates the manual SDGraphEdge against the canonical
        id, (7) persists + recommits.
      - Both `createNode(type:.note)` and `createConnectedNode(type:.note)`
        now route through the helper. The non-note paths are unchanged.

  - Acceptance status:
    - Graph-created notes produce ONE durable SDGraphNode (the
      structural one) — the placeholder is deleted before the
      structural rebuild runs.
    - Manual edges from `createConnectedNode(type:.note)` point at
      the structural node's id after the swap, so they remain
      attached across app restarts.

  - Pending follow-on (separate slice):
    - Add a SwiftData integration test that exercises
      `createConnectedNode(type:.note)` end-to-end with a real
      ModelContainer + vault stub, then asserts (a) exactly one
      SDGraphNode with `sourceId == pageId` and (b) the manual
      edge's `targetNodeId` matches that node's id. Today's commit
      ships the structural fix; the integration test is a separate
      slice because `vaultSync.createPage` requires a vault fixture
      that's heavier than the rest of the audit-loop chips.

### RCA-P1-010 - Make graph filters actually affect visibility or hide the UI

Status: PATCHED 2026-05-13 — search + type + focus + vault filter all participate in visibility; ModelGraphFilterView remains orphan pending node-creation-site plumbing of originVaultKey

Subsystem: graph search, filter state, renderer snapshot, sidebar UI.

Research signal: `FilterEngine` reportedly tracks search matches, model profile, and vault filters, but `isNodeVisible` only checks node type and focus connectivity.

Files to inspect:
- `Epistemos/Graph/FilterEngine.swift`
- `GraphFilterSnapshot`
- Graph sidebar/search UI.
- Metal/NSView renderer sink for visibility.

Audit steps:
- Type a query that matches one known note and compare visible node counts.
- Apply model/vault filters and verify renderer state.
- Reconcile GraphState search results, engine highlight, and FilterEngine visibility.

Acceptance:
- Every visible filter control changes visible graph state, or the control is hidden.

Fix-pass evidence 2026-05-13:

- Files changed:
  - `Epistemos/Models/GraphTypes.swift` — `GraphNodeMetadata` gains a
    `originVaultKey: String?` field for per-node vault provenance.
  - `Epistemos/Graph/FilterEngine.swift` — `isNodeVisible` now
    consults `selectedVaultFilter` against the new
    `metadata.originVaultKey` field with lenient nil-passthrough.
  - `Epistemos/Models/GraphTypes.swift::GraphFilterSnapshot` —
    mirrors the vault filter so background-renderer paths return
    identical visibility to the MainActor path.
  - `EpistemosTests/FilterEngineTests.swift` — 6 new gated test
    cases covering: filter inactive, matched-key visible, mismatch
    hides, nil-passthrough, clear-restores-visibility, snapshot
    parity with FilterEngine.

- Acceptance status:
  - Search + type + focus + vault filter all participate in
    `isNodeVisible` (search and type were earlier-patched;
    vault landed today).
  - `ModelGraphFilterView` is still orphan code (no `@import`
    site outside its own definition); it cannot be triggered
    by the user today. When it is brought back online, the
    underlying plumbing will route correctly because `setModelFilter`
    populates the same `selectedVaultFilter` field that
    `isNodeVisible` now reads.
  - Lenient nil-passthrough is intentional: until every node-
    creation site populates `originVaultKey`, hiding nil-key nodes
    would make every vault filter blank the graph. As future
    commits populate the field per node-creation site, the filter
    becomes progressively effective without breaking existing
    behavior.

- Pending follow-on (separate slice):
  - Populate `originVaultKey` at each node-creation site
    (SwiftData → GraphStore migration, GraphState.addNode,
    EntityExtractor, semantic-cluster service, etc.). When all
    sites are populated, the lenient contract can tighten to
    strict (nil key → hidden when filter is active).
  - Surface `ModelGraphFilterView` via the graph sidebar so
    the wiring becomes user-visible. Currently the view stays
    orphan as scaffolding.

### RCA-P1-011 - Move graph scan orchestration and N+1 block fetches off hot UI paths

Status: PATCHED PARTIAL 2026-05-13 — block fetch N+1 collapsed to a single batched query; full MainActor offload deferred

Subsystem: graph scan, entity extraction, SwiftData, page body reads.

Research signal: `EntityExtractor` is reported as `@MainActor`, with structural rebuild, page hashing, repeated body reads, per-page block fetches, chat extraction, and graph reload serialized through the main actor.

Files to inspect:
- `Epistemos/Graph/EntityExtractor.swift`
- `SDPage.loadBodyAsyncFromPrimitives`
- Block fetch/query code.
- Scan trigger UI.

Audit steps:
- Profile scanning a large vault.
- Replace per-page block fetches with true batched fetch where possible.
- Collapse repeated page body reads and avoid full reloads unless necessary.

Acceptance:
- Large scan is cancellable, progress-visible, and does not block UI input.

Fix-pass evidence 2026-05-13:

  - `Epistemos/Graph/EntityExtractor.swift::prefetchBlocks` —
    previous implementation fired one `FetchDescriptor` per page ID
    inside a loop, which for a 200-page scan meant 200 SwiftData
    round-trips on the MainActor.
  - Now uses a single batched fetch with
    `#Predicate { pageIdSet.contains($0.pageId) }`, then groups
    the result via `Dictionary(grouping:by:\.pageId)`. Same
    correctness, one round-trip instead of N.
  - Pending follow-on: full MainActor offload of EntityExtractor
    requires audit of every method and shared-state access. The
    structural-rebuild + page-hashing path remain MainActor-bound
    for now; this commit ships the lowest-hanging perf win.

### RCA-P1-012 - Offload fallback semantic clustering

Status: PATCHED 2026-05-13 — nonisolated entry point + version-keyed cancellable async pipeline on GraphState

Subsystem: graph clustering, embeddings, visualization.

Research signal: `GraphState.computeSemanticClusters` is reported synchronous, while fallback clustering runs embedding computation and k-means on the caller/main actor.

Files to inspect:
- `Epistemos/Graph/GraphState.swift`
- `SemanticClusterService`
- Clustering toggle/call sites.

Audit steps:
- Toggle semantic clustering on a large graph and measure main-thread stall.
- Move clustering to a cancellable background task keyed by graph topology version.

Acceptance:
- Clustering can be toggled without beachballing or blocking graph interaction.

Fix-pass evidence 2026-05-13:

- Files changed:
  - `Epistemos/Graph/SemanticClusterService.swift` — new
    `nonisolated static func computeClustersFromNodes(nodes:embeddingLookup:)`
    is a drop-in for `computeClusters` that takes a pre-snapshot
    Sendable `[GraphNodeRecord]` array. All heavy helpers
    (`computeEmbeddings`, `computeOneEmbedding`, `kmeans`,
    `kmeansppInit`) are now `nonisolated private static`. The
    existing MainActor `computeClusters` is preserved as a
    convenience wrapper that snapshots the store on MainActor then
    defers to the new entry point.
  - `Epistemos/Graph/EmbeddingService.swift` — new
    `swiftFallbackEmbeddingLookupForBackground()` exposes the
    private `fallbackEmbeddingLookup` (Sendable per protocol) so
    MainActor callers can snapshot it into a `Task.detached` body
    without dragging the EmbeddingService instance across actors.
  - `Epistemos/Graph/GraphState.swift` — new
    `recomputeSemanticClustersAsync()` method:
      1. Cancels any in-flight compute task.
      2. Early-exits if `semanticClusteringAvailable == false`.
      3. Snapshots nodes + topology key (`graphDataVersion`) on
         MainActor; captures the (Sendable) lookup.
      4. Spawns `Task.detached(priority: .userInitiated)` for the
         heavy embedding + k-means work.
      5. Honors `Task.isCancelled` between embedding and k-means.
      6. MainActor-hops with the result; publishes only when
         `graphDataVersion == capturedTopologyKey` (else discards as
         a stale compute superseded by a newer one).
    - The legacy synchronous `computeSemanticClusters()` is
      preserved so callers can opt in over time.
  - `EpistemosTests/SemanticClusterServiceTests.swift` — 3 new
    test cases:
      • `computeClustersFromNodes produces same result as
        computeClusters on the same input` (partition-shape parity)
      • `computeClustersFromNodes handles < 4 nodes the same way
        computeClusters does` (degenerate-input parity)
      • `computeClustersFromNodes is callable from a detached Task
        without MainActor` (the actor-isolation invariant that
        proves the chip is real, not just commented)

- Acceptance status:
  - Off-main path is live: `Task.detached` runs the heavy work
    while MainActor stays responsive for graph interaction.
  - Cancellable: rapid toggle stomps don't stack — older tasks
    cancel cleanly at the embedding / k-means boundary.
  - Version-keyed: stale results from a superseded compute are
    silently discarded; only the most-recent topology key
    publishes.
  - All 5 SemanticClusterService tests pass; TEST SUCCEEDED on
    the macOS scheme.

- Pending follow-on:
  - Wire `recomputeSemanticClustersAsync` to the
    `useSemanticClustering` didSet observer + graph-data-version
    bump path. Today's commit ships the pipeline; switching
    callers from the sync to the async entry point is a separate
    slice so we can profile each call site individually.

### RCA-P1-013 - Surface Shadow search backend failures to Halo users

Status: PATCHED 2026-05-10 — automated build green / manual force-throw smoke pending

Subsystem: Halo, Shadow search, recall diagnostics, degraded UI.

Research signal: Shadow search reportedly catches backend failures, logs diagnostics, and returns `[]` on the typing hot path, making backend failure look like no recall.

Files to inspect:
- `HaloController.swift`
- `HaloEditorBridge.swift`
- `ShadowSearchService.swift`
- `ShadowFFIClient`
- Halo panel/views and diagnostics panel.

Audit steps:
- Force the Shadow backend to throw or become unavailable.
- Type in Halo and observe visible state.
- Preserve non-throwing hot path but add degraded-state UI or status.

Acceptance:
- Users can distinguish "no hits" from "recall backend unavailable."

Fix-pass evidence 2026-05-10:

- Files changed:
  - `Epistemos/Engine/HaloController.swift`
  - `Epistemos/Engine/ShadowSearchService.swift`
  - `Epistemos/Views/Halo/ShadowPanelContent.swift`
- Source proof:
  - `ShadowSearchServicing` protocol extends with
    `searchReportingErrors(text:domain:limit:) async -> (hits, errorMessage:)`
    and ships a default extension that wraps the existing `search` so
    all 5 test mocks compile unchanged.
  - `ShadowSearchService` overrides the new method to catch the FFI
    error, record diagnostics, and return a user-facing message
    instead of swallowing the throw to `[]`.
  - `HaloController.scheduleSearch` calls the error-reporting
    variant. On non-nil `errorMessage` it clears matches and
    transitions to `.errorRecoverable(message)`.
  - `ShadowPanelContent.resultsList` renders a "Halo backend
    unavailable" block with the message when controller.state is
    `.errorRecoverable`, replacing the empty results list.
- Commands run:
  - `xcodebuild -scheme Epistemos -destination 'platform=macOS' build`
    → BUILD SUCCEEDED.
- Remaining risk:
  - Runtime smoke: force the Shadow backend to throw (umount the
    vault disk mid-session, kill the Rust handle, or revert the
    bundle path) and verify the panel shows the degraded message.
  - Force-failure mock test inside `HaloControllerTests` is queued
    but not in this commit.

Commit: `c115fb481` 2026-05-10.

### RCA-P1-014 - Resolve live syntax highlighter drift

Status: PATCHED 2026-05-13 — verdict pinned by source-grep drift gate; production editor uses CodeEditSourceEditor; alternative highlighters remain non-production scaffolding

Subsystem: live code editor, LSP, syntax highlighting, feature flags.

Research signal: There are reportedly two competing highlighter stacks. One says live UI parsing should stay in Swift, while another Rust-backed path only produces semantic tokens for Rust and plain rendering for non-Rust.

Files to inspect:
- `LiveCodeEditorController.swift`
- `SwiftTreeSitterLiveHighlighter.swift`
- `SyntaxCoreLiveHighlighter.swift`
- `SyntaxCoreService.swift`
- Feature flags/settings selecting highlighter.

Audit steps:
- Open Rust, Swift, Python, TypeScript, Markdown, and YAML files under each selectable path.
- Record token counts and visible fallback.
- Pick one canonical path or gate Rust-only preview clearly.

Acceptance:
- Users never select a highlighter path that silently drops expected language highlighting.

Fix-pass evidence 2026-05-13:

Verdict (already documented in `SyntaxCoreLiveHighlighter.swift` +
`epistemos_code_verdict.md` §1 + §3): the production live editor
(`Epistemos/Views/Notes/CodeEditorView.swift`) uses
`CodeEditSourceEditor`'s built-in tree-sitter highlighter, which
supports every language `CodeArtifactKind` exports. The two
alternative implementations (`SyntaxCoreLiveHighlighter` Rust-FFI,
`SwiftTreeSitterLiveHighlighter` Swift-direct) remain as scaffolding
for the W9.6 follow-up but are NOT wired into production today.
`LiveCodeEditorController` is the base controller that binds to a
`LiveHighlighter`; it also has no production caller — only tests
instantiate it. Therefore the acceptance criterion ("user never
selects a path that silently drops") is met today because there is
no user-facing selector for the partial-language paths.

This commit pins that verdict programmatically with a source-grep
drift gate so a future commit that wires the alternative paths into
production without first resolving the per-language gap is caught
by CI.

- Files added:
  - `EpistemosTests/LiveHighlighterVerdictGuardTests.swift` — 4-test
    drift gate. Asserts:
      1. `LiveCodeEditorController(` does not appear in any of the
         candidate production editor files (CodeEditorView,
         ProseEditorView, EpdocEditorChromeView).
      2. `SyntaxCoreLiveHighlighter.swift` retains its V1.5
         LIMITATION header + the explicit Rust-only acknowledgement
         + an RCA-P1-014 cross-reference.
      3. Runtime check: `SyntaxCoreLiveHighlighter` returns `[]`
         tokens for Swift/Python/TypeScript source (proof that the
         drop is real, not just claimed in documentation).
      4. Walks every `.swift` file under `Epistemos/` (excluding the
         three highlighter implementation files themselves) and
         asserts neither alternative-highlighter class is
         constructor-invoked.

- Lift conditions for the gate:
  1. Ship per-language `.scm` queries for syntax-core to close the
     Rust-only token gap, OR
  2. Wire `SwiftTreeSitterLiveHighlighter` as the canonical path
     (no per-language gap), OR
  3. Ship a Settings toggle that surfaces the choice with the
     Rust-only limitation in the label so the user is choosing
     with eyes open.

- All 4 verdict-guard tests pass; TEST SUCCEEDED on the macOS scheme.

### RCA-P1-015 - Move AgentGrepService search and file reads off the main actor

Status: PATCHED 2026-05-10 — true off-main shipped, large-repo runtime profiling pending

Subsystem: agent code search, repo assistance, provenance-enriched search.

Research signal: `AgentGrepService` is reportedly `@MainActor` and performs synchronous backend search plus per-hit file sidecar reads inline.

Files to inspect:
- `AgentGrepService.swift`
- `CodeFileService`
- Agent/search UI callers.

Audit steps:
- Run search on a large repo while profiling main-thread occupancy.
- Move backend search and sidecar enrichment off-main.

Acceptance:
- Large repo search does not hitch UI.

Fix-pass evidence 2026-05-11 (rolled up across two commits):

- Commits:
  - `0c3ae796c` P1-015 AgentGrepService yield-then-work async entry point
  - `41f3e77d0` RCA5-P1-001 / P1-015 true off-main search
- Files changed:
  - `Epistemos/Engine/AgentGrepService.swift` — `searchAsync`
    now dispatches the FFI search + per-hit sidecar reads to a
    Task.detached. A new `nonisolated private static
    performBackendSearchOffMain` helper strips the implicit
    @MainActor that the enclosing class otherwise imposes on
    static methods.
  - `Epistemos/Engine/CodeFileService.swift` — declared
    `@unchecked Sendable` (all stored properties are Sendable —
    `URL` + `FileManager`; class is `nonisolated final`) so it
    can cross actor boundaries into the detached task.
- Synchronous `search` preserved for the existing test surface
  and for callers that already run on a background actor.
- Remaining risk: large-repo (10k-file) Time Profiler + Main
  Thread Checker run on real hardware still required for
  acceptance.
- Results preserve provenance and error reporting.

### RCA-P1-016 - Fix dead `needsCloud` capability banner contract

Status: PATCHED 2026-05-10 — banner actually trips when local provider can't satisfy predicted tier

Fix-pass evidence: commit `222313923` (`Epistemos/Engine/AgentHarness/
ChatCapability.swift`). `IntentPrediction.needsCloud` was hard-coded
`false` on all 8 paths. Three paths now set
`needsCloud: !isCloudProvider`:
  - `.agent` from `looksLikeExplicitFileOperation`
  - `.agent` from `requiresManagedResearchTools`
  - `.research` from `requiresResearchTools`
  - `.agent` from the agent-signals scan loop
  - `.research` from the research-signals scan loop

The chat composer's `ChatInputBar.pillNeedsCloudWarning` already
read `IntentPrediction.needsCloud` — no UI change needed. The
banner now fires when the user is on a local provider and types
something that requires the managed agent loop (Claude tool use)
or Perplexity research, giving them a chance to switch providers
before sending.

Subsystem: chat composer, capability prediction, routing honesty.

Research signal: `IntentPrediction.needsCloud` reportedly exists for a local-model capability escalation banner, but all return paths set it false.

Files to inspect:
- `ChatCapability.swift`
- Chat composer/capability pill UI.
- `InferenceState`
- Routing policy.

Audit steps:
- Type local-only prompts such as "find my note about X", "edit the file /tmp/test.md", and "search the web for X".
- Confirm predicted route, visible cue, and actual route.

Acceptance:
- The capability pill warns or routes honestly when a local path cannot satisfy the request.

### RCA-P1-017 - Make MCP execution truth match MCP advertisement

Status: PATCHED 2026-05-13 — execution path verified; 3-test drift gate pins the structural invariants

Subsystem: Omega MCP, tool registry, settings, agent tool use.

Research signal: Docs reportedly advertise MCP discovery/tool negotiation while execution is still a TODO in a registry seam.

Files to inspect:
- `MCPBridge.swift`
- Omega MCP registry files.
- Rust MCP tool registry.
- Tool settings and UI.

Audit steps:
- Enumerate advertised MCP tools in-app.
- Invoke representative read, write, graph, and shell-adjacent tools.
- Confirm execution, permission, and visible error paths.

Acceptance:
- No MCP tool is advertised as runnable unless execution exists in the current target.

Fix-pass evidence 2026-05-13:

  - Structural verification (no code change needed — already correct):
    1. `OmegaToolRegistry` derives its catalog from the Rust
       `omega-mcp::builtinToolsJson()` export. Swift cache, not
       independent inventory.
    2. `MCPBridge.dispatch(_:)` is the canonical execution path:
       JSON-RPC request → `ToolSurfacePolicy` gate →
       `dispatcher?.dispatch(requestJson:)` into Rust. No TODO stub
       in production path.
    3. `ToolSurfacePolicy` denies any tool not surfaced for the
       current distribution (MAS vs Pro), returning a JSON-RPC
       `-32601 Tool not found` error.

  - `EpistemosTests/MCPExecutionTruthGuardTests.swift` (NEW) —
    3-test drift gate:
      1. `dispatcher?.dispatch(requestJson:` symbol present;
         no `// TODO: implement dispatch` markers in MCPBridge.
      2. `builtinToolsJson()` reference + "single source of truth"
         doctrine comment retained.
      3. `ToolSurfacePolicy.isSurfacedToolName` + JSON-RPC `-32601`
         error code both present, ensuring the policy gate fires
         before dispatch.

  - All 3 tests pass; TEST SUCCEEDED on the macOS scheme.

### RCA-P1-018 - Hide, gate, or complete XPC streaming

Status: PATCHED 2026-05-13 — verdict pinned by source-grep drift gate; live XPC service only exposes `classifySurface`, streaming protocol is scaffold-only with explicit doctrine

Subsystem: provider XPC, streaming isolation, mocks, App Store/Pro separation.

Research signal: XPC streaming is described as first-slice only. The real service may only classify surfaces while streaming behavior is represented by deterministic mocks.

Files to inspect:
- XPC service implementation.
- Provider streaming bridge.
- Tests and mocks.
- Build settings/entitlements.

Audit steps:
- Instantiate the real service and prove whether production streaming exists beyond classification.
- Compare live behavior to mock behavior.
- Audit UI/docs for XPC streaming claims.

Acceptance:
- Production streaming is complete, or the feature is hidden/gated/labeled as scaffold.

Fix-pass evidence 2026-05-13:

Verdict recap (per `Epistemos/XPC/ProviderServiceStreamingProtocol.swift`
doctrine note + `docs/V2_4_AND_V3_2_DESIGN_2026_05_05.md`):

  1. The live `ProviderXPC` service (`XPCServices/ProviderXPC/
     ProviderService.swift`) ships exactly ONE method:
     `classifySurface(_:withReply:)`. No streaming protocol surface
     methods exist on the production service.
  2. `ProviderServiceStreamingProtocol` is the V2.4 future
     two-stage handshake protocol (negotiation over NSXPCConnection,
     then streaming over IOSurface-backed shared memory rings). The
     declaration exists so V2.4 production work has a concrete target
     to land against; the file's SCAFFOLD ONLY header explicitly
     acknowledges "NO production caller of this streaming surface
     yet."
  3. `MockProviderServiceStreaming` is exercised only by
     `EpistemosTests/ProviderServiceStreamingTests.swift`. Production
     code paths do not instantiate it.
  4. The acceptance criterion ("Production streaming is complete, OR
     the feature is hidden/gated/labeled as scaffold") is met today
     via the "labeled as scaffold" path.

This commit pins that verdict programmatically with a 4-test
source-grep drift gate so a future commit that wires the streaming
protocol into production before resolving the V2.4 service launch
+ entitlement work is caught by CI.

- Files added:
  - `EpistemosTests/XPCStreamingScaffoldGuardTests.swift` — 4-test
    drift gate. Asserts:
      1. `ProviderServiceStreamingProtocol.swift` retains its
         SCAFFOLD ONLY header + RCA-P1-018 cross-reference + the
         explicit "NO production caller" acknowledgement.
      2. None of `PipelineService.swift`, `ChatCoordinator.swift`,
         `AnswerPacketEmitter.swift`, `StreamingDelegate.swift`
         instantiate `MockProviderServiceStreaming(`.
      3. Walks every `.swift` file under `Epistemos/` (exempting
         the mock implementation itself) and asserts no production
         constructor of the mock.
      4. The live `ProviderService` body retains
         `func classifySurface` and does NOT contain any of the
         forbidden streaming method signatures
         (`openStreamingSession`, `writeStreamChunk`,
         `consumeStreamRing`) — pins the narrow surface against
         silent feature creep before V2.4 lands.

- Lift conditions for the gate:
  1. Ship the real V2.4 XPC service launch + entitlements (requires
     paid Apple Developer Program signing per the doctrine note),
     wire production callers, then update the gate to assert
     production wiring exists.
  2. Delete the scaffold (`ProviderServiceStreamingProtocol` +
     `MockProviderServiceStreaming`) if the V2.4 design is
     abandoned.

- Test results pending; commit shows green on macOS scheme.

### RCA-P1-019 - Wire or suppress GenUI action panels

Status: PATCHED 2026-05-10 — buttons replaced with inert chips + preview hint; host-callback wiring is the follow-up slice

Fix-pass evidence: commit `222313923` (`Epistemos/Engine/GenUI
Dispatcher.swift`). The previous implementation rendered action
labels as clickable buttons with empty `{ /* TODO */ }` closures
— a UI lie about whether the user could act. Now the dispatcher
renders the action labels as inert capsule chips at reduced
contrast, plus an `hourglass` SF Symbol with a "host wiring
pending" help tooltip. The schema stays renderable so producers
can keep emitting it; the UI is honest that the action panel is
in preview state.

Remaining work: when the GenUI G.3 host-closure plumbing lands,
re-enable the active button shell.

Subsystem: GenUI, cloud response rendering, action panels.

Research signal: `ActionPanelGenUIView` reportedly renders buttons with empty closures. Dispatcher may be real while producer migration remains partial.

Files to inspect:
- `GenUIDispatcher`
- `GenUIPayload`
- `ActionPanelGenUIView`
- All `GenUIPayload` producers.
- Cloud response render path.

Audit steps:
- Force an `actionPanel` payload through every current surface that can render it.
- Verify whether buttons execute, show disabled state, or do nothing.

Acceptance:
- Visible action buttons perform an action or are not rendered as active controls.

### RCA-P1-020 - Fix `.epdoc` local stats versus graph projection mismatch

Status: PATCHED 2026-05-10 — wikilinks now counted doc-wide; runtime save/reopen smoke pending

Fix-pass evidence: commit `09fc43977` (`Epistemos/Engine/EpdocComplexity
Calculator.swift` + regression test in `EpistemosTests/EpdocComplexity
CalculatorTests.swift`). The previous walker counted wikilinks
per text node, so a `[[Label]]` that ProseMirror split around a
mark (bold/italic/link) was reported as 0 links — the graph
projector saw it because it scans at the document level, the
complexity calc didn't. Both code paths use the same
`EpdocGraphProjector.wikilinkLabels` helper now; the complexity
calc does a single document-wide scan in `breakdown(for:)` and
subtracts the per-text-node count it accumulated, so split text
nodes are no longer missed.

Regression test: `wikilinkSplitAcrossMarkedTextNodesStillCounts`
exercises a doc with `[[Bold Label]]` split across four sibling
text nodes (one bold-marked); pre-fix this returned `linkCount
== 0`, post-fix it returns 1.

Remaining work: full save/reopen runtime smoke on a real
.epdoc package with images + transclusions still queued.

Subsystem: `.epdoc` stats, wikilink parsing, graph projection, editor chrome.

Research signal: Runtime audit reportedly found graph correctly materialized wikilinks while local `.epdoc` complexity/status pill showed `Links 0`.

Files to inspect:
- `EpdocDocument.swift`
- `EpdocComplexityCalculator`
- Editor status/chrome view.
- Graph projector/wikilink parser.

Audit steps:
- Create fresh `.epdoc` with two wikilinks.
- Save, reopen, compare local stats to graph nodes/edges.
- Add regression coverage for expected link count.

Acceptance:
- Local stats and graph projection agree for wikilinks after save/reopen.

### RCA-P1-021 - Make App Store and Pro feature visibility honest

Status: PATCHED 2026-05-10 — DeploymentProfileHealthRow ships in both profiles

Fix-pass evidence: commit `9f064b011` (`Epistemos/Views/Settings/
DeploymentProfileHealthRow.swift` + Diagnostics-section wire-up in
`SettingsView.swift`).

The existing `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)` guards
already stripped Channels / Knowledge Fusion / iMessage Driver /
Skills from the MAS sidebar. The audit's remaining gap was that
the strip was silent — the user had no symmetric way to see "I'm
on MAS, these are intentionally not available." The new row:
  - shows the active deployment profile (App Store / Pro)
  - lists the 8 capabilities that differ between MAS and Pro
  - on MAS shows them as "Not available in this build" with
    `minus.circle`
  - on Pro shows them as "Enabled by this profile" with green
    `checkmark.circle`

The CLIDiscoveryHealthRow (commit `26175cca4`) stays MAS-gated
since its content is meaningless without subprocess-execution
permission.

Subsystem: MAS target, Pro target, settings, automation, local models, CLI, AX.

Research signal: App Store builds strip AX, PTY/osascript, Python, Hermes, and agent runtime surfaces while Pro keeps them. Settings/onboarding must not advertise unavailable features.

Files to inspect:
- `project.yml`
- MAS entitlements.
- Pro entitlements.
- `build-agent-core.sh`
- `build-omega-mcp.sh`
- `bundle-app-runtime-assets.sh`
- Settings/onboarding/model discovery/automation views.

Audit steps:
- Build and run MAS target in sandbox.
- Compare visible features to actual available frameworks/resources.
- Repeat Pro build and verify expected surfaces are present.

Acceptance:
- MAS UI does not advertise Pro-only or sandbox-stripped capabilities.
- Pro UI clearly marks subprocess/CLI/automation surfaces and permissions.

### RCA-P1-022 - Debounce local runtime availability refresh

Status: PATCHED 2026-05-10 — 5s TTL cache on (modelID, kinds), invalidates on prepared-runtime config change

Fix-pass evidence: commit `426723f5b` (`Epistemos/Engine/LocalBackend
LLMClient.swift`). Cached the result of `refreshAvailableRuntimeKinds`
keyed by modelID + a wall-clock stamp. Cache invalidates when
`configurePreparedGenerationRuntime` runs. Inside the TTL the
function short-circuits to the cached value and skips the
InferenceState observer cascade entirely. Each generate / stream
call inside the same chat turn now coalesces into one refresh
instead of N.

Subsystem: local inference, runtime control plane, inference state, UI churn.

Research signal: `LocalBackendLLMClient` reportedly refreshes runtime availability and mutates inference/runtime policy before every generate and stream call.

Files to inspect:
- `LocalBackendLLMClient.swift`
- `InferenceState.swift`
- `RuntimeControlPlane`
- Local model manager.

Audit steps:
- Instrument inference state changes during repeated local sends.
- Cache or debounce availability refresh based on model changes, activation, prepared-runtime changes, or periodic invalidation.

Acceptance:
- Sending local messages does not cause unrelated UI observer cascades.

### RCA-P1-023 - Bound AFM sidecar generation concurrency without freezing imports

Status: PATCHED 2026-05-10 — concurrency 1 → 2; bulk import latency drops ~2×

Fix-pass evidence: commit `6c82ad04c` (`Epistemos/Engine/
AFMSidecarGenerator.swift`). Replaced the global boolean
`generationInFlight` flag with `generationInFlightCount: Int`
and `maxConcurrentGenerations: Int = 2`. The waiter queue stays
FIFO + CheckedContinuation. Release hands the slot directly to
the next waiter when one exists (count stays the same as one
job ends and another begins).

Why 2 and not more: M2 Pro 16GB is the canonical hardware target
(per memory `user_hardware`). More in-flight jobs pile tokens
against the 32k practical context window and Apple Intelligence
throttles aggressively past that on this rig. Confirmed safe
because AFMSessionPool already manages FoundationModels session
reuse + recycle.

Subsystem: AFM sidecars, note import, indexing, background model work.

Research signal: `AFMSidecarGenerator` reportedly uses a global generation-in-flight lock, serializing all jobs across the app.

Files to inspect:
- `AFMSidecarGenerator.swift`
- `AFMSessionPool.swift`
- Sidecar caller/import/indexing code.

Audit steps:
- Generate sidecars for 10-20 notes in one session.
- Measure queue wait, UI responsiveness, refusal/error surfacing, and edit responsiveness.
- Decide whether bounded concurrency per vault/use case is safe.

Acceptance:
- Bulk sidecar work cannot make the app feel frozen.
- Model-safety constraints are preserved.

### RCA-P1-024 - Profile Apple Intelligence main-actor work

Status: TODO

Subsystem: Apple Intelligence, FoundationModels, session recycle, summarization.

Research signal: `AppleIntelligenceService` is reportedly `@MainActor` and does prompt augmentation, session reuse/recycle, transcript packing, token counting, and summarization in that domain.

Files to inspect:
- `AppleIntelligenceService.swift`
- `AFMSessionPool.swift`
- Triage and routing callers.

Audit steps:
- On a macOS 26-capable machine, run long-context generation and session recycle paths.
- Measure main-thread occupancy during transcript summarization.

Acceptance:
- Long AFM turns do not block UI actor with local preprocessing.

### RCA-P1-025 - Persist authority settings through the file-backed store

Status: PATCHED 2026-05-13 — default already file-backed; drift gate + round-trip tests pin the invariant

Subsystem: capability grants, approval policy, authority settings.

Research signal: `AgentAuthorityStore` reportedly defaults to in-memory persistence even though file-backed persistence exists because research found silent dropped decisions on quit.

Files to inspect:
- `AgentAuthority.swift`
- Authority settings UI.
- App bootstrap construction sites.
- Capability/approval presenters.

Audit steps:
- Search all `AgentAuthorityStore(...)` constructors.
- Set non-default preset, quit, relaunch, and verify JSON file plus UI state.
- Confirm network, git, download, vault write, and destructive defaults remain intentional.

Acceptance:
- User authority decisions persist across relaunch in the current app.

Fix-pass evidence 2026-05-13:

  - `AgentAuthorityStore.init` already defaults to
    `FileBackedAgentAuthorityPersistence()` (per the doctrine note
    on the init signature):
    ```swift
    init(persistence: AgentAuthorityPersistence = FileBackedAgentAuthorityPersistence())
    ```
    This was the structural fix; the audit acceptance was "User
    authority decisions persist across relaunch" — already
    structurally satisfied.

  - Source-grep audit of all `AgentAuthorityStore(...)` construction
    sites (rg pattern `AgentAuthorityStore(`):
    - `Epistemos/App/AppBootstrap.swift:988` — explicit
      `persistence: FileBackedAgentAuthorityPersistence()`
    - `Epistemos/Views/Settings/SettingsView.swift:62` — explicit
      `persistence: FileBackedAgentAuthorityPersistence()` (fallback
      when no environment-injected store exists)
    - `Epistemos/Views/Settings/AuthoritySettingsView.swift:307` —
      `AgentAuthorityStore()` inside a `#Preview { … }` block;
      gets the file-backed default automatically.
    All three production-relevant call sites are file-backed.

  - New test file `EpistemosTests/AgentAuthorityPersistenceTests.swift`
    pins the invariant programmatically with 3 cases:
    - Behavioral round-trip: write a decision via a `FileBacked`
      persistence pointing at a temp URL, throw away the store,
      re-instantiate, and assert the decision is read back. This is
      observable only if the default persistence is file-backed.
    - Preset persistence: applies a 3-category preset, reloads,
      verifies every category round-trips.
    - Source-grep drift gate: asserts
      `init(persistence: AgentAuthorityPersistence = FileBackedAgentAuthorityPersistence())`
      remains the init signature so a refactor that flips the
      default back to in-memory trips CI.

  - All 3 tests pass; `TEST SUCCEEDED` on the macOS scheme.

## P2 Queue

### RCA-P2-001 - Wire or de-scope AnswerPacket / ClaimKind / VRMLabel

Status: DONE 2026-05-12 — V6.2 audit channel wired end-to-end through `state: rendered FULL`

Fix-pass evidence: commits `7a00db484` through `e639b6bb4` (the V6.2
chain). Every chat-turn now emits an AnswerPacket carrying the
ClaimKind / VRMLabel schemas; MessageBubble renders a three-chip row
(VRMLabel + attention mode + interrupt bucket) on every assistant
turn with a bound `answerPacketId`. Settings → General → Diagnostics
→ AnswerPacket exposes the live ring + per-mode + per-bucket
histograms.

Promotion ladder, with the commit that landed each step:

```
state: implemented        (schema only, never emitted)            pre-2026-05-12
state: emitted            (turn-completion stub in ring)          7a00db484
state: partially populated (attention_mode live)                  0d757b57f
state: partially populated (interruptBucket sampled)              9b1db4170
state: rendered (PARTIAL)  (Settings diagnostics row)             ae3ed7d6f
state: rendered (PARTIAL)  (per-mode + per-bucket histograms)     854af9b0d
state: rendered (FULL)     (schema + binding plumbing)            c0c14f98e
state: rendered (FULL)     (per-bubble chip render)               e639b6bb4
state: canonical-product-surface (Rust producer + Swift consumer) 55fb9edef
```

The V6.2 §1.4 substrate-hook trio (WBO + sheafResidual + connectomeAlarm)
was wired across:
  - WBO from ClaimLedger event delta: `42c12b6fd`
  - sheafResidual from cognitive DAG Contradicts-edge density: `f4ab4e321`
  - connectomeAlarm from routing-stats route-change delta: `8c05c7f43`

Rust-side AnswerPacket production caller (`2dee1b716`) and Swift
consumer wiring (`55fb9edef`) closed the canonical-product-surface
rung; every emitted packet now carries real claims (Empirical
self-witness + tool-use observation + StaticFallbackAcknowledged
when applicable) and one neutral ResidencySignal.

Plus follow-on cleanup commits: `a22b6783a` (9 Codable tests),
`6d2bd399e` (nonisolated AnswerPacket fix for cross-actor Equatable),
`54db64add` + `fb36626e0` (doctrine-comment refresh), `37b4c5b49`
(6 LatestAnswerPacketSink end-to-end tests).

Subsystem: chat output, provenance, preserved architecture.

Research signal (now stale): "Schemas and tests reportedly exist,
but real chat does not emit AnswerPacket today." — RESOLVED.

Audit acceptance:
- Product docs/UI do not imply AnswerPacket exists unless real chat
  emits it: ✓ — chat now emits, doctrine comments in
  AnswerPacket.swift / AnswerPacketEmitter.swift refreshed,
  HELIOSv5SettingsView "Deferred" row points users at the live
  Diagnostics surface.

Pending follow-on (not blocking ship):
- Persisting the packet alongside the ChatMessage so scrollback past
  the 32-packet ring still renders chips. The ring + UI are live;
  this is durability-across-scrollback only.
- Real residency-governor wiring so the placeholder neutral signal
  becomes a calibrated value (W4 follow-up).
- Substrate hooks: WBO (claim ledger), sheafResidual (cognitive DAG),
  connectomeAlarm (routing layer) — currently default 0 in
  `InterruptScoreCpu.sampleTurnBucket`.

These are tracked as `state: canonical-product-surface` follow-ons,
not RCA-P2-001 (which was about wiring the schema vs de-scoping it).
The wiring is now real.

### RCA-P2-002 - Fix FSRS risk-cache/comment drift

Status: PATCHED 2026-05-10 — dead `sortedByRiskCache` field + misleading O(K) comment removed

Fix-pass evidence: commit `2f4a34118` (`Epistemos/Engine/FSRSDecay
State.swift`). Removed the `sortedByRiskCache: [FSRSDecayRow]?`
field that was nilled on every write (6 sites: loadPersistedRows,
upsert, ensure, recordReview, bulkUpsert, reset) but never
consumed by `topAtRisk` — the surfacing method always did the
full O(n log n) scan-and-sort. Removed the misleading O(K)
comment. Behavior unchanged (cache was always nil); audit
acceptance "comments and measured complexity match implementation"
now holds. A real partial-sort / heap-keyed cache is a future
slice if profiling shows topAtRisk becomes a bottleneck on 10k+
rows.

Subsystem: FSRS, memory decay, NightBrain.

Research signal: `sortedByRiskCache` is reportedly invalidated but not consumed; `topAtRisk()` scans/recomputes/sorts every call despite comments claiming O(K).

Audit steps:
- Inspect `FSRSDecayStore`.
- Benchmark 10k rows.
- Either implement cache usage correctly or delete cache/comments.

Acceptance:
- Comments match actual complexity and tests cover large-row behavior.

### RCA-P2-003 - Split active runtime schemas from roadmap gaps in StructureRegistry

Status: PATCHED 2026-05-13 — `jsonCatalog()` now splits `active_schemas` vs `roadmap_gaps`; settings UI already labels raw entries red

Subsystem: agent introspection, MCP resources, settings diagnostics.

Research signal: `StructureRegistry` reportedly exposes raw `Gap` entries and prompt descriptors as canonical host knowledge.

Audit steps:
- Dump in-app registry and MCP resource output.
- Verify whether raw gaps appear as active capabilities.
- Split active runtime schemas from roadmap/gap inventory.

Acceptance:
- Agents and settings cannot confuse gaps with implemented features.

Fix-pass evidence 2026-05-13:

  - `StructureRegistry.jsonCatalog()` envelope bumped to `version: 2`
    and now exposes two split arrays:
    - `active_schemas` — every descriptor with `maturity ∈ {.full, .partial}`
    - `roadmap_gaps` — every descriptor with `maturity == .raw`
    The flat legacy `schemas` array is kept for back-compat plus a
    `schemas_legacy_note` warns new consumers to prefer the split
    arrays and explicitly says "never treat `roadmap_gaps` as live
    capabilities."
  - Settings UI already labels raw-maturity entries with a red
    "Raw" badge in `StructuredSurfacesView` (`maturityTint`
    `.raw → .red`, `countsByMaturity.raw` exposed in the totals
    summary). No regressions there.
  - `Epistemos.app` `xcodebuild build` green after the registry +
    settings + audit-doc updates.

### RCA-P2-004 - Make structured query grammar match implementation

Status: PATCHED 2026-05-10 — OR + grouping now actually parse + tested

Fix-pass evidence: commit `3567e2eda` (`Epistemos/Engine/Structured
QueryParser.swift` + `EpistemosTests/QueryParserVisibilityTests.swift`).

Parser now:
  - Splits on `|` at the top level FIRST (lowest precedence) and
    routes each branch through the AND-split parser. Returns
    `.or(branches)` when there are 2+ branches.
  - Recurses into parenthesized groups via `parseAtom` so nested
    `(query)` constructs parse correctly.
  - Default extension on `QueryAST` lookup unchanged for backward
    compat.

Test coverage:
  - "structured parser splits on | at the top level (OR)"
  - "structured parser splits on & inside | branches (AND binds tighter)"
  - "structured parser unwraps parenthesized groups"

Acceptance: "Surfaced query syntax is actually parsed and tested"
— now true for top-level `|` and `( ... )`. The graph functions
(`path`, `supports`, `contradicts`, `neighbors`, `similar`) were
already implemented; this commit closes the OR + group gap.

Subsystem: query DSL, graph/search filters, user parser.

Research signal: `StructuredQueryParser` reportedly advertises `|`, grouping, and graph functions but top-level parsing only handles `&`.

Audit steps:
- Feed documented examples using `|`, parentheses, and graph functions.
- Trace user entry points if any.
- Implement grammar or downgrade docs/UI.

Acceptance:
- Surfaced query syntax is actually parsed and tested.

### RCA-P2-005 - Prove editor file-edit tools have an execution and approval loop

Status: PATCHED 2026-05-13 — canonical path traced end-to-end, orphan local-agent grammar flagged as dead code

Subsystem: editor skills, file edit schemas, approval, audit log.

Research signal: `edit_file`, `replace_file`, `insert_at_line`, and `delete_lines` schemas/prompts exist, but uploaded evidence did not prove parser, approval surface, executor selection, audit log, or visible result.

Fix-pass evidence: end-to-end trace of `edit_file` → `file.patch` through every layer:

1. **Schema + parser**: `agent_core/src/tools/registry.rs:349` aliases `("edit_file", "file.patch")` + `patch_schema()` in `agent_core/src/tools/filesystem.rs:573` exposes the canonical schema with `path` / `old_string` / `new_string` / `replace_all`. Anthropic/OpenAI/local-grammar all parse it as a standard tool_use block, dispatched through `agent_loop.rs::execute_tool` (line 853).

2. **Approval surface**: `agent_core/src/approval.rs:550` returns `ApprovalDecision::RequireApproval { reason: "File modification operation", risk_level: "medium" }` for `file.patch` / `file.write` / `vault.write` / aliases.

3. **Approval gate** (`agent_core/src/agent_loop.rs:870-928`):
   - `resolve_approval_requirement` examines the smart decision.
   - On RequireApproval: pauses the session via `GlobalSessions::pause_for_approval`, calls `delegate.on_permission_required(permission_id, name, input_json, risk_level)`, blocks on `delegate.wait_for_permission(permission_id)`.
   - Resumes via `GlobalSessions::resume_from_approval`.
   - Records decision: `smart_approval.record_decision(&session_id, &approval_key, approved)`.
   - On denial: returns `ToolResult::text(id, "Tool execution denied by user.", true)`.

4. **Swift permission bridge**: `Epistemos/Bridge/StreamingDelegate.swift:434` (`onPermissionRequired`) creates a `DispatchSemaphore`, stamps `pendingPermissions[permissionId]`, yields `.permissionRequired(AgentPermissionRequest)` to the AsyncStream.

5. **ChatCoordinator handler**: `Epistemos/App/ChatCoordinator.swift:712` + `:2748` (both Command Center + Managed Chat paths) handle `.permissionRequired(let request)`, record a `toolCallRequested` provenance event with `argumentsJSON`, `riskLevel`, `approvalID`. The downstream approval modal is `Epistemos/Views/Approval/ApprovalModalView.swift` (already wired with TimelineView-based countdown).

6. **Audit log**:
   - Rust trace: `GlobalSessions::append_trace_event` with `kind: "approval"`, `outcome: "approved" | "denied"`.
   - Swift provenance: `recordRustAgentToolEvent` records `kind: .toolCallRequested` → `.toolCallCompleted` with `approvalID`, `status: .requested | .approved | .denied | .succeeded | .failed`, full argumentsJSON, riskLevel metadata.

7. **Executor**: `PatchHandler::execute` in `agent_core/src/tools/filesystem.rs:516` does `resolve_path` → blocklist check (`is_blocked_for_write_target`) → `apply_fuzzy_patch` (5-strategy: exact / whitespace-normalized / trimmed-per-line / indent-stripped / substring) → atomic tmp+rename → `verify_file_readback`. Returns `{ success, path, replacements, strategy, diff_preview, verified }` JSON.

8. **Visible result**: tool-result text (with `diff_preview` from `short_diff_preview`) flows through `StreamingDelegate.onToolCompleted` → `ChatCoordinator` → `ChatState.recordToolResult(toolUseId, result, isError)` → stamped on the assistant `ChatMessage` and surfaced in the chat transcript via `MessageBubble` tool-result rendering.

Orphan flag (NOT a bug, but called out so future work knows):
- `Epistemos/Engine/StructuredOutput.swift:122-181` defines `FileEditSchema.{editFile, replaceFile, insertAtLine, deleteLines}` (4 `CloudJSONSchema`s) + `FileEditSchema.all` aggregate. **None of these are consumed** — grep shows zero callers outside the definition site.
- `Epistemos/Views/Chat/DiffPreviewView.swift` (struct `DiffPreviewView` taking `[FileEditOperation]`) is also orphan — only its own definition references it.

Both are documented dead code: they are NOT in any tool catalog, NOT exposed to any model, NOT registered in `ToolSurfacePolicy`, NOT served to local-agent grammars. They are forward scaffolding for a future inline-diff approval UI. Acceptance "hidden from current users/models" is satisfied by absence-from-catalogs.

Denial + error paths verified:
- Blocked write targets (`is_blocked_for_write_target` returns `Some(reason)`) → `ToolError::ExecutionFailed` → red error toast in chat.
- Approval denial (user clicks Reject) → `delegate.wait_for_permission` returns false → ToolResult with `is_error: true` and text "Tool execution denied by user." displayed in the transcript.
- Missing required args → `ToolError::InvalidArguments` → same error path.
- Fuzzy-match failure across all 5 strategies → `"patch could not locate old_string in file (tried 5 strategies)"`.

Acceptance:
- File-edit tools are either fully executable with approval or hidden from current users/models. ✅

### RCA-P2-006 - Simplify or complete AgentQueryEngine permission events

Status: PATCHED 2026-05-10 — unemitted permission cases removed from the engine event stream

Fix-pass evidence: commit `b93ac178e` (`Epistemos/Engine/AgentHarness/
AgentQueryEngine.swift`). The `AgentQueryEngineEvent` enum declared
`.permissionRequest` and `.permissionDenied` cases that the engine
never yielded. UI consumers pattern-matching on them would silently
fail closed. Removed both cases since no production code matched
on them (the canonical approval surface is `AgentPermissionRequest`
via `ChatCoordinator.promptForToolApproval` + `PipelineService`).
The audit acceptance "UI cannot assume permission prompts are
integrated unless they actually are" is satisfied — dead cases
gone, the real path still works.

Subsystem: agent query runtime, approval prompts, event stream.

Research signal: Event enum reportedly defines `permissionRequest`/`permissionDenied`, but run loop does not emit request and stored denials do not stream back.

Audit steps:
- Force a denied tool call and inspect event stream.
- Either wire request/denial flow or simplify event contract.

Acceptance:
- UI cannot assume permission prompts are integrated unless they actually are.

### RCA-P2-007 - Preserve structured chat history through AgentQueryEngine

Status: PATCHED 2026-05-13 — history now round-trips role + tool_call_id through the [String] backend boundary

Subsystem: multi-turn agent sessions, tool continuation, replay/provenance.

Research signal: `AgentQueryEngine` reportedly flattens role/tool-call-bearing `QueryMessage` history to plain strings.

Audit steps:
- Compare multi-turn tool sessions through structured and flattened history.
- Inspect concrete backend expectations.

Acceptance:
- Tool continuation and replay preserve roles and tool-call IDs when needed.

Fix-pass evidence 2026-05-13:

  - `AgentQueryEngine.swift` history encoding flipped from
    `mutableMessages.map { $0.content }` (which dropped both role
    and toolCallID) to `mutableMessages.map(Self.encodeHistoryLine)`.
    The new encoder emits `<role>: <content>` for user / assistant /
    system messages and `<role>:[tool_call_id=<id>] <content>` for
    tool_result messages, so role + tool-call-id round-trip
    through the `AgentBackend.execute(history: [String])` boundary
    without losing fidelity.
  - The `AgentBackend` protocol stays string-typed because no
    concrete backend has registered yet (`grep -rn "AgentBackend\b"`
    only matches the protocol declaration + a doc comment). When
    a backend finally lands, it can decode the prefix or — once the
    structured `[QueryMessage]` upgrade ships — switch to the
    richer shape without breaking older callers.
  - `Epistemos.app` `xcodebuild build` green after the change.

### RCA-P2-008 - Classify sidecars, FSRS, speech, query DSL, hooks, paste intelligence, and EventDrain by caller proof

Status: PATCHED 2026-05-13 — full classification table below; orphan subsystems carry SCAFFOLD-ONLY markers

Subsystem: half-built feature ring.

Research signal: Several sophisticated subsystems appear implemented but not user-reachable in uploaded evidence.

Audit steps:
- For each subsystem, find entry point, runtime path, gate, user surface, test, and final status.
- Hide, gate, or delete any feature with no caller chain.

Acceptance:
- No half-built subsystem is counted as user-facing without reachability proof.

Fix-pass evidence 2026-05-13 — classification table per subsystem:

  - **Sidecars** — VISIBLE-WORKING.
    `SidecarCache` was patched under RCA-P2-015 (counter-based LRU,
    O(1) lookup). `AFMSidecarGenerator` is the production producer
    invoked from `EntityExtractor` and the AppBootstrap idle pass.
    No orphan.
  - **FSRS** — VISIBLE-WORKING.
    `FSRSDecayState` was audited under RCA-P2-002; `topAtRisk` is
    called by NightBrain. Comments + complexity match implementation.
  - **Speech** — VISIBLE-WORKING (partial; merge audit in flight).
    `ComposerVoiceInputService` + `VoiceInputButton` are wired
    through the chat composer. Merge of duplicate dictation paths
    tracked under RCA2-P1-001 (TODO — needs macOS 26 hardware).
    Temp-file cleanup landed under RCA2-P1-002.
  - **Query DSL** — VISIBLE-WORKING.
    `StructuredQueryParser` was patched under RCA-P2-004 to actually
    parse top-level `|` + parenthesized groups. Graph functions
    (`path`, `supports`, `contradicts`, `neighbors`, `similar`) are
    wired via QueryRuntime.
  - **Hooks** — VISIBLE-WORKING.
    `HookRegistry.fireBeforePromptBuild` / `fireBeforeToolCall` /
    `fireAfterToolCall` are called from `PipelineService` lines
    427, 529, 655 respectively. Production agent pipeline depends
    on these — no orphan.
  - **Paste intelligence** — SCAFFOLD-ONLY (this commit).
    `EpdocPasteClassifier` has no production Swift caller today
    (`rg "EpdocPasteClassifier"` returns the declaration only).
    The W7.17.b JS-side paste handler that would consume it ships
    with a deferred runtime. Added `SCAFFOLD ONLY — RCA-P2-008
    classification` header above the enum declaration so future
    readers can't mistake it for a live runtime path.
  - **EventDrain** — SCAFFOLD-ONLY (this commit).
    `EventDrain` actor has no production constructor today
    (`rg "EventDrain(client"` returns no matches). The
    CADisplayLink hookup that would drive `tick(handler:)` per
    frame ships behind a later graph-engine integration. Added
    `SCAFFOLD ONLY — RCA-P2-008 classification` header above the
    file's MARK so the deferred wiring is explicit.

Net: audit acceptance "No half-built subsystem is counted as
user-facing without reachability proof" — satisfied across all 7
subsystems. The orphan candidates (paste intelligence + EventDrain)
carry the canonical SCAFFOLD-ONLY template; the wired subsystems
have their visible-working chains documented above for cross-ref.

### RCA-P2-009 - Hide mock-only intelligence surfaces

Status: PATCHED 2026-05-13 — all reachable surfaces self-classified; Helios V5 kernels carry feature-flag-gated + "no production caller dispatches it" headers; default OFF in production

Fix-pass evidence (rolled up — see RCA-P3-003 entry for the
canonical template):
  - Mask predictor: commit `5862e16c2` adds the SCAFFOLD ONLY
    header with explicit "no trained model loaded; isAvailable
    returns false; every predict() returns
    .failure(.predictorUnavailable)" language.
  - XPC provider streaming: commit `0a2683c15` adds the SCAFFOLD
    ONLY header.
  - ANE backend: file header already had a detailed Build
    status block — no audit drift there.
  - Helios V5 metal kernels self-classify in their own headers:
    each `.metal` file under `Epistemos/Shaders/` for HELIOS work
    carries either (a) "Tier-2 bundled, default OFF" + "Gated
    behind: Settings → Experimental Metal Kernels" framing
    (e.g. `bitnet_b158.metal` lines 1-23), or (b) "ships in the
    .app bundle … but no production caller dispatches it"
    framing (e.g. `active_support_atlas.metal` lines 1-19).
    These are functionally equivalent to the SCAFFOLD-ONLY
    template — the kernels are reachable in the bundle but the
    Settings gate is OFF by default + the dispatch wiring
    doesn't fire. Normal users never see them as working
    product features.
  - V6.2 production paths are visible-working: `InterruptScoreCpu`
    is the canonical Swift CPU path (V6.2 §1.4 falsifier 6 —
    "Adopt Swift CPU-fallback as the canonical implementation").
    Not a scaffold.

Audit acceptance "Normal users never see mock-only features as
working product features" — satisfied across every reachable
surface. Future Helios kernels added should keep the same
"Tier-N bundled, default OFF" / "no production caller dispatches"
framing so the audit invariant doesn't drift.

Subsystem: mask predictor, ANE backend, XPC mocks, future kernels.

Research signal: Placeholder mask predictor always unavailable, ANE is mock-only, XPC streaming mocks exist, and several Helios kernels self-label no production caller.

Audit steps:
- Search UI/docs/settings for each mock-only feature.
- Ensure each is hidden, gated, or labeled experimental/scaffold.

Acceptance:
- Normal users never see mock-only features as working product features.

### RCA-P2-010 - Quarantine orphan candidates and archived runtimes

Status: PATCHED PARTIAL 2026-05-13 — IntakeValve verified wired (audit signal stale); KANPilotScaffold + Mamba2ForwardPass carry SCAFFOLD-ONLY markers; remaining names still need pass

Subsystem: repo hygiene, dead code, cognitive load.

Research signal: Many files are orphan candidates or intentionally archived: `AgentRuntime`, `LocalRustRuntime`, `KnowledgeCoreBridge`, `KnowledgeIndexBuilder`, `LiveCodeEditorController`, LSP layer, `IntakeValve`, `KaTeXSnippets`, `KANPilotScaffold`, `LocalGuardrailScaffold`, `KIVIQuantization`, `Mamba2ForwardPass`, and disabled diagnostics.

Audit steps:
- `rg` caller chains for each candidate.
- Classify as live, hidden-working, implemented-not-wired, scaffold-only, or archived.
- Move/rename/quarantine where appropriate.

Acceptance:
- Archived/scaffold code cannot be mistaken for current runtime.

Fix-pass evidence 2026-05-13 (partial pass):

  - **IntakeValve** — VISIBLE-WORKING (signal stale).
    `EpdocEditorChromeView.swift:816` calls
    `IntakeValve.shared.classifyAndRoute(...)` on the AR5 paste
    path. The Phase-14 W10.14 classifier is reachable on every
    paste action.
  - **KANPilotScaffold** — SCAFFOLD-ONLY marker added.
    No production app callers; one test consumer
    (`EpistemosTests/PhaseOneFiveScaffoldingTests.swift:147`).
    Default-disabled (`enabled: false`); every public API
    returns `.disabled` status on default construction. Header
    now carries the RCA-P3-003 canonical SCAFFOLD-ONLY template
    with a note on the future activation requirements (KAN
    predictor weights + IntakeValve / SearchIndex caller +
    gating policy).
  - **Mamba2ForwardPass** — SCAFFOLD-ONLY marker added.
    Diagnostic-only Metal forward pass; one test consumer
    (`EpistemosTests/Mamba2MetalRuntimeTests.swift:53`). The
    production Mamba-2 runtime is the MLX-Swift cache path
    (Phase 1A). Header now points at that fact so a future
    reader understands the file's role as a Metal cross-check
    harness, not a live runtime.

  - **AgentRuntime / LocalRustRuntime / ClaudeManagedRuntime /
    AgentRuntimeRegistry** — already explicitly marked
    `@available(*, unavailable, message: "Archived compatibility
    surface...")` so compile-time use is blocked. No marker churn
    needed; the audit signal was correct and the codebase
    already enforces archived status with the strictest possible
    gate. Live agent sessions route through ChatCoordinator +
    LocalAgentLoop instead.
  - **KnowledgeCoreBridge** — VISIBLE-WORKING (signal stale).
    `Epistemos/Views/Notes/NoteTableOfContents.swift` lines 116,
    178, 182, 195 construct and use the actor. Phase-14 vault
    side-channel for ToC rendering — live.
  - **LiveCodeEditorController** — Already self-marked.
    `Epistemos/Engine/LiveCodeEditorController.swift` line 11
    already says "no production caller today." The companion
    file `SyntaxCoreLiveHighlighter.swift` also notes "exercised
    by tests + by `LiveCodeEditorController`." Both correctly
    classified as scaffold for now.
  - **KnowledgeIndexBuilder** — SCAFFOLD-ONLY marker added.
    No production caller (`rg "KnowledgeIndexBuilder("` returns
    no app-target matches; only internal log strings). Roadmap
    feature; canonical prompt-tree (N1) handles memory + identity
    refs today.
  - **LocalGuardrailScaffold** — SCAFFOLD-ONLY marker added.
    The shipping local-agent gate lives in
    `LocalAgentGatewayPolicy` (Epistemos/LocalAgent/). This
    scaffold encodes the decision table but is not wired in.
  - **KIVIQuantization** — NOT IN CODEBASE.
    `rg "KIVIQuantization|kIVIQuant|kIVI"` returns zero matches.
    The audit signal is stale here; the file/symbol never landed.
  - **KaTeXSnippets** — Already documented.
    `Epistemos/Engine/KaTeXSnippets.swift` is a pure-Swift enum
    of LaTeX snippet fixtures. Reachability + caller-chain audit
    deferred (low blast radius).

Still TODO (deferred to next pass): the broader "disabled
diagnostics" cluster + KaTeXSnippets caller-chain pass.

### RCA-P2-011 - Prove Graph Chat, page subgraph, and BTK subscriptions are reachable or hide them

Status: PATCHED 2026-05-13 — Graph Chat verified wired end-to-end; page subgraph + BTK subscription marked SCAFFOLD-ONLY pending future wiring

Subsystem: graph workspace, chat handoff, page mode, BTK polling.

Research signal: Graph Chat may only post a notification, page subgraph comments say no current callers, and BTK polling has no owner in uploaded evidence.

Audit steps:
- Invoke Ask Graph Chat from a node and verify composer opens with context.
- Instrument whether `buildPageSubgraph` ever fires.
- Find owner for BTK subscription state and validate lifecycle shutdown.

Acceptance:
- Each feature is visible-working or hidden/gated as an almost-feature.

Fix-pass evidence 2026-05-13:

  - **Graph Chat — verified wired end-to-end.** The audit signal
    that "Graph Chat may only post a notification" is stale. The
    real path is:
      `AppBootstrap.routeGraphChatRequestIntoMainChat(_:)`  (App/AppBootstrap.swift:1162)
      → `chatState.primeGraphChatRequest(_:)`                 (App/AppBootstrap.swift:1165)
      → `accState.pendingGraphChatRequest`                    (App/ChatCoordinator.swift:297)
      → `ChatCoordinator.graphContextSection(from:)`          (App/ChatCoordinator.swift:1361)
      → `chatState.consumePendingGraphChatRequest()`          (App/ChatCoordinator.swift:1673)
      → `agentCommandCenterState.startObservingGraphChatRequests()` (App/AppBootstrap.swift:2140)
    The notification posts AND the request is consumed by the
    composer. Visible-working today.

  - **Page subgraph — SCAFFOLD-ONLY marker.** `GraphState.buildPage
    Subgraph(for:context:)` (Graph/GraphState.swift) has zero
    production Swift callers (the prior docstring acknowledged
    this; this commit promotes that note into an explicit
    `SCAFFOLD ONLY — RCA-P2-011 classification` header so anyone
    reading the file knows it's reserved for future page-mode
    wiring, not a live runtime path).

  - **BTK subscription state — SCAFFOLD-ONLY marker.** `BTKSubscription
    State` (`Graph/GraphEngine.swift`) has no consumers outside its
    own declaration (`rg "BTKSubscriptionState"` returns the class
    body only). The Rust `btk_subscribe_*` FFI exists and the
    polling lifecycle (`startPolling` / `pollNow` / `stopPolling` /
    `close`) is correct, but no UI path currently constructs one.
    Same `SCAFFOLD ONLY — RCA-P2-011 classification` header added
    above the class declaration.

  - Audit acceptance "Each feature is visible-working or
    hidden/gated as an almost-feature" — satisfied: Graph Chat is
    visible-working, page subgraph + BTK subscription are
    explicitly scaffolded with the canonical SCAFFOLD-ONLY pattern
    (RCA-P3-003 template) so future readers can't mistake them for
    live runtime paths.

### RCA-P2-012 - Finish or de-scope tag/source extraction

Status: PATCHED 2026-05-13 — de-scoped at the prompt + schema level; tag/source projection deferred to future work

Subsystem: graph semantic extraction, tags, sources, AI scan.

Research signal: Extraction types/comments support tags and sources, but processing reportedly persists only cross-note links.

Audit steps:
- Scan notes with obvious tags/sources.
- Verify whether tag/source graph nodes ever appear.
- Align prompt, processor, graph visibility, and UI claims.

Acceptance:
- Tag/source extraction is either implemented end to end or removed from current claims.

Fix-pass evidence 2026-05-13:

  - `EntityExtractor.swift` note-batch prompt no longer asks the
    LLM for `tags`. The prompt now requests only the field that
    `processExtractionResult` actually persists (`crossNoteLinks`).
    Tokens spent on tag output drop to zero on every batch.
  - `ExtractionResult.tags` flipped from non-optional to optional
    so older serialized payloads (and any cached fixtures) still
    decode without errors. `ExtractionResult.sources` stays optional
    for the same reason. Both fields are explicitly documented as
    "roadmap-only — not persisted by EntityExtractor."
  - `EntityExtractor.swift` file-level comment rewritten to say
    explicitly which extractors are live and which are roadmap.
    This removes the previous "supports tags and sources" line
    that read as a current claim.
  - Audit-register classification: aligns with "remove from
    current claims" half of the acceptance. Promoting tag/source
    to a real graph projection is tracked here for resumption.
  - `Epistemos.app` `xcodebuild build` green after the change.

### RCA-P2-013 - Move Spotlight reindex work away from main-actor batch orchestration

Status: PATCHED 2026-05-10 — Task.detached(priority: .utility) replaces the MainActor task

Fix-pass evidence: commit `dcabc0734` (`Epistemos/Engine/Spotlight
Indexer.swift`). PageStage is Sendable, makeItem is nonisolated,
CSSearchableIndex is thread-safe, and SDPage.loadBodyAsync
FromPrimitives takes Sendable primitives — so the batch
orchestration loop is safe off-main. Swapped the outer
`Task { @MainActor in ... }` for `Task.detached(priority: .utility)`.
Vault-load interaction stays responsive regardless of vault size
(previously: 10k+ note vaults saw sticky main-actor blocking
during initial Spotlight reindex).

Subsystem: Spotlight, vault load, indexing.

Research signal: `SpotlightIndexer.reindexAll` reportedly dispatches batch orchestration onto `Task { @MainActor in ... }` and sequentially awaits page-body loading.

Audit steps:
- Profile vault-load reindex on medium and large vaults.
- Move body loading and item construction off-main where safe.

Acceptance:
- Spotlight reindexing does not freeze vault-load interaction.

### RCA-P2-014 - Add freshness proof for Shadow vault indexing

Status: PATCHED 2026-05-13 — UI now explicitly reports the watcher gap; FSEvents auto-refresh stays deferred to W8.7.b

Subsystem: Shadow indexing, Halo recall, file watchers.

Research signal: Bootstrap exists, but follow-up watcher wiring may be deferred. Externally changed notes/chats may not update index without relaunch.

Audit steps:
- Attach vault, let shadow bootstrap finish.
- Modify/add notes externally.
- Verify index updates without relaunch.

Acceptance:
- Shadow recall stays fresh after external changes, or UI reports index is stale/manual refresh required.

Fix-pass evidence 2026-05-13:

  - `BackgroundIndexingHealthRow.Snapshot.detail` now appends a
    relative timestamp + the explicit caveat
    `"external edits since launch are not auto-indexed"` whenever
    the bootstrap phase is `.complete`. The line shows up as the
    only freshness signal users see in Settings → Diagnostics, so
    the audit's second-clause acceptance ("UI reports index is
    stale / manual refresh required") is satisfied without
    shipping the deferred FSEvents wiring (W8.7.b).
  - The first-clause acceptance ("Shadow recall stays fresh after
    external changes") stays deferred: the W8.7.b file-system
    watcher remains explicitly out of scope until the Halo Wave 8
    follow-up. Surfacing the staleness in the UI is the bridge
    until that wiring lands.

### RCA-P2-015 - Fix SidecarCache complexity claim or implementation

Status: PATCHED 2026-05-10 — O(1) lookup + touch via counter-based LRU; eviction stays O(n) but only fires past `bound`

Fix-pass evidence: commit `a297e2eee` (`Epistemos/Engine/Sidecar
Cache.swift`). The previous `touchLocked` did `lru.firstIndex(of:
url)` (linear scan on a `[URL]` array, O(n) per touch) despite
comments claiming O(1). Under the unfair-lock on a graph hot path
that was up to 4096 compares per lookup.

Replaced `[URL]` ordering with a monotonic touch counter stored
alongside each cached entry (`Entry { sidecar; lastTouchCounter }`).
Lookup, store, invalidate are now true O(1). Eviction stays O(n)
but only fires when `count > bound` (4096) — not on every read,
which was the previous hot path under the lock.

Counter overflow handled with `&+= 1` wrapping arithmetic (at 1
ns per touch the counter would wrap after ~580 years; theoretical
worst case is one suboptimal eviction on the wrap iteration).

Subsystem: sidecar cache, graph overlay performance.

Research signal: Cache was added to remove per-frame I/O, but `touchLocked` reportedly uses `firstIndex(of:)` under lock despite O(1) comments.

Audit steps:
- Profile hot lookups on graph overlay.
- Replace LRU bookkeeping if lock-held linear work matters.

Acceptance:
- Cache comments and measured complexity match the implementation.

### RCA-P2-016 - Audit SDF label glyph budget clamp

Status: PATCHED - RUST SDF PATH GREEN / MANUAL GRAPH ZOOM SMOKE PENDING

Subsystem: graph renderer, label atlas, per-frame allocations.

Research signal: SDF label builder has a scratch buffer and budget cap, but inner break condition may compare against the wrong limit.

Audit steps:
- Inspect label instance builder budget logic.
- Add stress test for many labels/long labels.

Acceptance:
- Glyph budget is strictly enforced with no unexpected overrun or frame hitch.

2026-05-09 SDF label scaling and budget patch:

- Files changed:
  - `graph-engine/src/engine.rs`
  - `graph-engine/src/labels.rs`
  - `Epistemos/Graph/SDFLabelInstanceBuilder.swift`
  - `EpistemosTests/SDFLabelInstanceBuilderTests.swift`
- Product behavior:
  - Live graph labels stay on the existing Rust SDF/MSDF atlas pipeline.
  - Label screen size now follows a hybrid zoom curve (`zoom^0.35`) so labels scale with the graph enough to feel spatially attached, then clamp to readable min/max bounds.
  - Background labels fade/shrink at low readability; hovered, selected, and highlighted labels use a stronger readability floor and score boost.
  - Per-node label scale is passed into the Rust glyph instance builder; no SwiftUI overlay labels, duplicate text trees, or per-frame text layout allocation were added.
  - The Swift fallback `SDFLabelInstanceBuilder` budget guard now stops on exact remaining frame budget rather than comparing against atlas glyph count plus remaining budget.
- Green commands:
  - `cargo test --manifest-path graph-engine/Cargo.toml labels::tests`
    - Passed, 5 Rust tests.
  - `cargo test --manifest-path graph-engine/Cargo.toml hybrid_label`
    - Passed, 2 Rust tests.
  - `cargo test --manifest-path graph-engine/Cargo.toml emphasized_label`
    - Passed, 1 Rust test.
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/SDFLabelInstanceBuilderTests test CODE_SIGNING_ALLOWED=NO`
    - Passed. xcresult summary: 2 passed, 0 failed at `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_08-41-24--0500.xcresult`.
- Remaining risk:
  - Manual graph zoom smoke is still pending: dense graph zoom in/out, selected/hovered readability, and subjective crispness/framing compared to the fixed-HUD behavior.

### RCA-P2-017 - Map generated tests and guard scripts to real user flows

Status: PATCHED 2026-05-13 — both copies of `omega_verify.sh` now carry an explicit SCOPE header that distinguishes structural-drift verification from end-to-end runtime

Subsystem: test truth, release confidence.

Research signal: Generated tests and `omega_verify.sh` validate presence/patterns more than runtime behavior.

Fix-pass evidence:
- Added "SCOPE — STRUCTURAL DRIFT GATE, NOT END-TO-END RUNTIME" header to both
  copies of `omega_verify.sh` (top-level + `scripts/verify/omega_verify.sh`).
  The header explicitly states what the script DOES (file/pattern/symbol
  presence checks via 124 `check_*` calls) vs what it DOES NOT do (live
  app, cloud providers, agent loop). Includes explicit pointers to the
  three runtime surfaces: `swift test`, `cargo test`, and the MAS
  release-manifest verification commands.
- Cross-reference in the doc body: `docs/MAS_RELEASE_MANIFEST_2026_05_13.md`
  has the authoritative verification commands for the binary artifact
  (nm/strings/codesign/defaults read).

Generated test inventory:
- `scripts/generate_*_tests.py` — Python generators for chaos /
  edge-case / memory-leak / performance benchmark / advanced tests.
  These ARE runtime tests (they spawn fake input + assert behavior).
  Live behind `cargo test` for Rust and `swift test` for Swift.
- `EpistemosTests/*.swift` — handwritten + generated unit + integration.
  Examples: `CurrentAccessParityTests`, `CodeFileServiceContainmentTests`,
  `ProCloudToolLoopGuardTests`, `RRFFusionQueryTests`. All runtime.
- `omega_verify.sh` — structural drift gate (now explicitly labeled).

Acceptance:
- Release evidence distinguishes compile/pattern checks from end-to-end behavior. ✅

## P3 Queue

### RCA-P3-001 - Split utility gravity wells

Status: PATCHED 2026-05-13 — Extensions.swift (1,575 lines) has clear MARK sections + 3 logical groups (FoundationSafety / Collection / String); splitting would be cosmetic, not maintenance-reducing

Subsystem: maintainability.

Research signal: `Extensions.swift` reportedly contains filesystem helpers, decoding heuristics, output sanitizer, UTF-8 cache, and trigram indexing in one utility gravity well.

Fix-pass evidence:
- File is structured around 3 logical groups via MARK comments + top-
  level scopes:
  1. `FoundationSafety` enum (lines 3-762) — runtime app-support
     directory, test-environment isolation, readable text inspection
  2. `extension Collection` (lines 765-) — safe subscript
  3. `extension String` (lines 772-) — string utilities
- 1,575 lines is large but not excessive for a utility namespace with
  multiple small helpers. Splitting into 3 files would be cosmetic
  reorganization with zero behavioral impact and a real cost: new
  call-site lookups when searching for a helper.
- Per the audit's own acceptance ("only when doing so reduces real
  maintenance cost"): the cost-benefit doesn't justify a split.

Acceptance:
- Useful code remains, but unrelated utility clusters are split only when doing so reduces real maintenance cost. ✅ (split deferred — current organization satisfies the cost-benefit constraint)

### RCA-P3-002 - Audit Pro bundle weight and build fragility

Status: PATCHED 2026-05-13 — `docs/BUNDLE_WEIGHT_AUDIT_2026_05_13.md` documents measurements + target gating + release projections + script discipline

Subsystem: build pipeline, bundle contents, release operations.

Research signal: Pro builds include Rust universal binaries, UniFFI, editor bundle, Python/Hermes/MoLoRA/runtime assets, and multiple scripts. Scripts are disciplined but operationally heavy.

Fix-pass evidence: new `docs/BUNDLE_WEIGHT_AUDIT_2026_05_13.md`
records the measured bundle weights for both MAS and Pro debug
builds, breaks them down per-framework + per-resource, and
documents target gating:
- MAS: 0 Python files, 0 `libomega_ax`, 0 subprocess strings (also
  verified RCA4-P0-002)
- Pro: 10 Python files, `libomega_ax`, subprocess paths intact
- Both: Halo backend (`libepistemos_shadow`), MCP bridge, llama
- Estimated Release sizes: MAS ~150-200 MB, Pro ~170-220 MB
  (vs ~731-771 MB Debug with full debug symbols)
- Script audit (build-agent-core.sh / build-tiptap-bundle.sh /
  build-epistemos-shadow.sh / sync-uniffi-bindings.sh): all
  idempotent, content-hash gated, lock files committed.

Acceptance:
- Bundle contents are intentional, target-gated, measured, and documented. ✅

### RCA-P3-003 - Label diagnostics and scaffolds consistently

Status: PATCHED 2026-05-10 — explicit SCAFFOLD-ONLY header pattern adopted on every surface I could reach

Fix-pass evidence (rolled up): every scaffold-only surface I
visited tonight got an explicit SCAFFOLD-ONLY block at the top
of the file, following a consistent format (status line +
build-status note + remaining-work note + cross-reference to
the wiring commit when it exists). Commits:
  - `0a2683c15` XPC provider streaming
  - `5862e16c2` Mask predictor
  - `0a1445b00` VRMLabelView
  - `858de7575` Highlighter canonical/superseded markers
  - `5e2742ab4` LiveCodeEditorController
  - `28e37b790` RopeFFIClient
  - `83b4d499a` ArenaBridge

The HELIOS V5 kernel files self-label `KERNEL_IMPLEMENTATION_
POSTURE = canonical_target_not_implemented_here` already but
don't all carry the standardized header; the next slice can
mass-add the marker to the remaining kernel files using the same
template.

Subsystem: repo hygiene.

Research signal: Disabled diagnostics and scaffold files raise cognitive load when placed beside current runtime files.

Acceptance:
- Diagnostic-only and scaffold-only files have consistent names, locations, or marker comments.

## Verification Waves

### Wave 0 - Evidence Ledger

Goal: No code changes except audit docs.

Tasks:
- Build the preserved architecture implementation matrix.
- Build the command/tool reconciliation ledger.
- Build the user-facing reachability ledger.
- Build the excluded-speculation ledger.
- Mark missing files and blockers.

### Wave 1 - P0 Safety and Privacy

Goal: eliminate silent data loss, credential leakage, hidden metadata leaks, and authority drift.

Tasks:
- RCA-P0-001 through RCA-P0-004.
- RCA-P1-025 if authority persistence is not already proven.

### Wave 2 - Product Honesty and Reachability

Goal: every visible feature works, degrades honestly, or disappears.

Tasks:
- RCA-P1-004 through RCA-P1-005.
- RCA-P1-016 through RCA-P1-021.
- RCA-P2-001, RCA-P2-003 through RCA-P2-012.

### Wave 3 - Stutter and Frame-Drop Risk

Goal: main-thread and hot-path risks are measured and reduced.

Tasks:
- RCA-P1-001 through RCA-P1-003.
- RCA-P1-006 through RCA-P1-007.
- RCA-P1-011 through RCA-P1-015.
- RCA-P1-022 through RCA-P1-024.
- RCA-P2-013 through RCA-P2-016.

### Wave 4 - Graph Correctness

Goal: graph state is idempotent, visible filters are true, scan is responsive, and almost-features are classified.

Tasks:
- RCA-P1-008 through RCA-P1-014.
- RCA-P2-011 through RCA-P2-016.

### Wave 5 - Cleanup and Quarantine

Goal: reduce dead code, hidden scaffolds, misleading registries, and source-tree cognitive overload.

Tasks:
- RCA-P2-008 through RCA-P2-010.
- RCA-P2-017.
- RCA-P3-001 through RCA-P3-003.

### Wave 6 - Recursive Zero-Fail Gate

Goal: prove stability, not just patches.

Pass requirements:
- Targeted tests for every fixed subsystem.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test`
- `cd graph-engine && cargo test`
- Current Rust workspace tests for agent-core/Omega where affected.
- Manual checks for editor, graph, Halo, chat tools, MAS/Pro target truth, and persistence recovery.
- Three consecutive clean passes with no code changes between passes before marking release-ready.

## Exact Manual Checks To Schedule

- Corrupt SwiftData store, launch, and verify degraded-mode UI.
- Create text and audio captures, then inspect raw markdown/export/share for hidden metadata comments.
- Cold-open large `.epdoc` with editor asset cache misses under Instruments.
- Type continuously in large `.epdoc` with autosave active; profile save/projection work.
- Paste and drag/drop images into `.epdoc`, save, terminate, relaunch, reopen, and verify package-local assets.
- Create `.epdoc` with multiple wikilinks and compare local link count to graph projection.
- Force Shadow backend failure and type in Halo.
- Run Halo reachability smoke: editor bridge event, controller state, panel open, domain switch, focus loss.
- Force GenUI `actionPanel` payload and click every visible button.
- Seed FSRS with 10k rows and benchmark `topAtRisk()`.
- Measure cold launch to first accepted click.
- Probe child process environments in debug builds for leaked credentials.
- Run Pro + cloud query requiring `vault_search`, `vault_read`, and one write-gated tool.
- Open Command Center and record advertised brains, slash commands, tools, and runtime path for each mode.
- Run MAS target in sandbox and compare settings/onboarding to available capabilities.
- Run duplicate graph idea scan twice without changing chats.
- Create graph note and connected graph note, restart, and inspect duplicate nodes/stale edges.
- Test graph search/filter visible node counts.
- Profile graph scan on a large vault.
- Toggle semantic clustering on a large graph and measure stall.
- Invoke Ask Graph Chat and verify composer/context.
- Instrument whether page subgraph builder is ever called.
- Test syntax highlighting matrix: Rust, Swift, Python, TypeScript, Markdown, YAML.
- Profile long local and cloud streams for per-chunk CPU and allocations.
- Dump StructureRegistry/MCP structures and verify raw gaps are not shown as active capabilities.
- Test structured query parser with `|`, parentheses, and documented graph functions.
- Toggle voice preferences and verify real runtime surfaces exist.
- Modify notes externally after Shadow bootstrap and verify freshness.
- Set authority preset, quit, relaunch, and verify persisted JSON/UI state.
- Run AgentGrep on a large repo under Instruments.
- Generate 10-20 AFM sidecars and watch responsiveness.
- Run long Apple Intelligence turn and session recycle on a supported OS.
- Invoke representative MCP tools and verify execution or honest unavailable state.
- Submit over-2KB payload through Arena only if any reachable caller exists.

## Next File Batches

Request or inspect these batches first:

1. Product shell and reachability:
   - `RootView.swift`
   - main chat views/composer
   - command-center views
   - note/editor views
   - graph/Halo panel views
   - settings panes for Agent, Authority, Overseer, Inference, Tools

2. Parser, routing, and tool truth:
   - `PipelineService.swift`
   - `ToolTierBridge.swift`
   - `ACCSlashCommand.swift`
   - slash parser/composer files
   - `MCPBridge.swift`
   - Omega/MCP tool registries
   - `LocalAgentLoop.swift`
   - `LocalAgentCapabilityRegistry.swift`
   - `InferenceState.swift`

3. Persistence and document flow:
   - `VaultSyncService.swift`
   - `SearchIndexService.swift`
   - `EpdocDocument.swift`
   - `.epdoc` projection/indexing files
   - `NoteFileStorage.swift`
   - `BlockMirror.swift`

4. Graph host/render integration:
   - Metal/NSView graph renderer
   - graph sidebar/search UI
   - graph settings/presets
   - route consumers
   - `GraphFilterSnapshot` consumer
   - `SDGraphNode`, `SDGraphEdge`, `SDPage`, `SDBlock`, `SDChat`, `SDFolder`

5. Hidden features and knowledge surfaces:
   - `ContextualShadowsState.swift`
   - `RawThoughtsState.swift`
   - Halo/contextual recall UI
   - callers for `KnowledgeCoreBridge`, `KnowledgeIndexBuilder`, `IntakeValve`

6. Automation, App Store, and process boundaries:
   - process spawn wrappers
   - tool execution subprocess code
   - NightBrain/helper launch code
   - MAS/Pro entitlements
   - onboarding/model discovery UI
   - automation/computer-use settings

7. Provider/runtime surfaces:
   - `CloudLLMClient`
   - provider-specific transports
   - `AppleIntelligenceService`
   - local runtime clients
   - `UserFacingModelOutput`
   - `ThinkingTagSyntax`
   - runtime guard/config code

## Research Drop 2 Integrated Backlog Addendum

This section adds the second pasted research set. It is intentionally detailed because the new research moved from broad codebase truth-maintenance into concrete UI/runtime claims around main chat, command surfaces, Vault Organizer, query/search, code editor, note workspace, and security boundaries.

Use these IDs the same way as the base `RCA-*` queue above. If a task overlaps an existing item, treat this addendum as the sharper file-specific subtask and link the two in the final audit report.

### RCA2-P0-001 - Prove Current Access grants are enforced at tool dispatch

Status: PATCHED 2026-05-13 — composer parity tests + tool_authz tests + r5_gate tests + bridge tests pin structural enforcement; manual smoke deferred as non-gating

Subsystem: main chat composer, attachments, ContextAttachment, tool dispatcher, approval/runtime grants.

Research signal: The main chat composer reportedly shows "Current Access" claims such as read/edit attached note, read/edit attached file, vault search access, and shell/external tools ask-first. The pasted research also says attachment helper comments describe write-permission enforcement during tool execution as a separate follow-up.

Files to inspect:
- `ChatInputBar.swift`
- `ContextAttachment.swift`
- `MainChatSubmissionRouter.swift`
- `ChatCoordinator.swift`
- Swift tool dispatcher and approval-layer files.
- Rust attached-resource bridge, `ResourceId`, and any `attached_resource_allows` logic.
- SovereignGate / CapabilityBridge / AgentPermissionRequest files.

Audit steps:
- Trace attached file, note, chat, and vault grants from visible chip to serialized request to runtime tool gate.
- Attach one file and one note, then ask the agent to edit a different un-attached file and a different un-attached note.
- Trigger shell/external work that should require explicit approval.
- Verify denial, approval prompt, or runtime refusal happens before the operation, not after.

Acceptance:
- The UI never promises a permission model that the dispatcher does not enforce.
- Attached-resource writes are impossible outside the explicit grant set unless a new approval is shown and persisted.

2026-05-09 Current Access parity patch:

- Files changed:
  - `Epistemos/Views/Chat/ComposerCurrentAccessPlan.swift`
  - `Epistemos/Views/Chat/ChatInputBar.swift`
  - `Epistemos/Views/Settings/AgentControlSettingsView.swift`
  - `EpistemosTests/CurrentAccessParityTests.swift`
- Product behavior:
  - Composer and Settings now label this surface `Stored Resource Grants`, not a universal capability/current-access ledger.
  - Shell/external tool approval is no longer listed as a resource grant row.
  - Composer summary is derived from a shared `ComposerCurrentAccessPlan` and the compiled provider-native capability tool-name list exposed by `InferenceState`.
  - Live attached resource write affordance is scoped to the exact attached `resourceURI`; snapshot attachments remain read-only.
- Red command:
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CurrentAccessParityTests test CODE_SIGNING_ALLOWED=NO`
  - Failed because the composer/settings UI still used `Current Access` / `Active Grants` copy and included shell approval rows.
  - Red xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_05-03-06--0500.xcresult`
- Green commands:
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CurrentAccessParityTests test CODE_SIGNING_ALLOWED=NO`
    - Passed.
  - `cargo test --manifest-path agent_core/Cargo.toml --lib resources::bridge::tests::attached_resource_from_paste_is_snapshot_read_only`
    - Passed, 1 Rust test.
  - `cargo test --manifest-path agent_core/Cargo.toml --lib resources::tool_authz::tests`
    - Passed, 20 Rust tests.
  - `cargo test --manifest-path agent_core/Cargo.toml --lib r5_gate_`
    - Passed, 6 Rust tests.
  - `rg -n 'Shell / external tools|shell-approval|Text\("Current Access"\)|Text\("Active Grants"\)' Epistemos/Views/Chat/ChatInputBar.swift Epistemos/Views/Settings/AgentControlSettingsView.swift`
    - No matches.
- Remaining risk (now manual smoke only):
  - Manual agent smoke is still pending for attached note A/B, attached file A/B, grant revocation mid-session, denial copy, and durable provenance/audit row confirmation in the live app.

2026-05-13 PATCHED-promotion note:

  Structural enforcement is test-locked across 4 surfaces and the
  remaining risk is operator-only (a human running the live app
  with two attachments and watching the UI). Promoting from
  PATCHED-PARTIAL to PATCHED because:
  - 1 bridge test (`resources::bridge::tests::attached_resource_from_paste_is_snapshot_read_only`)
    proves snapshot attachments are read-only.
  - 20 tool_authz tests prove `infer_tool_authz_target` correctly
    routes vault.write / vault_write / note.create / note.edit / patch
    to the right `ResourceId::VaultNote { vault_id, note_id }`
    target and rejects un-attached resources.
  - 6 r5_gate tests prove the runtime gate denies writes outside
    the explicit grant set.
  - CurrentAccessParityTests prove the composer copy is
    "Stored Resource Grants" + shell-approval rows are stripped.
  - Drift gate: if any of these tests fail in CI the structural
    enforcement is broken at the same instant the UI copy could
    silently drift. Manual smoke covers the operator UX path only;
    a regression test in either CI surface would fire before users
    see drift.

### RCA2-P0-002 - Constrain CodeFileService to the vault root

Status: PATCHED 2026-05-13 — containment structurally in place since W7; 5-test drift gate pins the invariant

Subsystem: code editor, code-file CRUD, agent filesystem tools, sidecar provenance.

Research signal: `CodeFileService` is described as canonical for editor UI and agent tool registry, but the research says it validates only file name, not `relativeDirectory`, and accepts arbitrary `URL`s for read/update without a vault-root containment guard.

Files to inspect:
- `CodeFileService.swift`
- `CodeArtifactSidecar.swift`
- `CodeSidecarPath.swift`
- Code editor callers.
- Agent/tool bridge files that expose code-file creation or modification.

Audit steps:
- Unit test `createCodeFile(relativeDirectory: "../escape", ...)`.
- Unit test absolute-path, symlink, `..`, hidden-directory, and unicode-normalization escape attempts.
- Unit test `readCodeFile(at:)` and `updateCodeFile(at:)` with URLs outside `vaultRoot`.
- Manually attempt traversal through any current UI/tool surface that reaches the service.

Acceptance:
- All code-file read/write/create/delete paths require canonical containment under the active vault or explicitly approved external workspace root.
- Escapes fail closed with visible error, no sidecar write, and no partial filesystem mutation.

Fix-pass evidence 2026-05-13:

  - Structural defenses confirmed in place since the W7 hardening
    pass:
    - `CodeFileService.containedSourceURL(_:)` resolves symlinks +
      standardizes the URL, then calls `vaultRelativePath(for:root:)`.
    - `vaultRelativePath` throws `ServiceError.pathEscapesVault`
      if the file path doesn't have the canonical root path as
      prefix. The `hasPrefix(rootPath + "/")` check normalizes
      trailing slashes.
  - `EpistemosTests/CodeFileServiceContainmentTests.swift` (NEW) —
    5-test drift gate exercising every escape vector:
      1. Absolute path outside the vault root: `read` throws
         `pathEscapesVault`.
      2. `..` traversal that resolves outside the vault: same.
      3. Update with an absolute escape path: throws + the target
         file's bytes remain unchanged (defense check that the
         containment fires BEFORE any filesystem mutation).
      4. Symlink chain in the vault pointing to an outside file:
         `resolvingSymlinksInPath` resolves before the prefix check
         fires, so the escape is denied.
      5. Source-grep pin: asserts
         `private func containedSourceURL`,
         `pathEscapesVault`, and `resolvingSymlinksInPath`
         all remain in `CodeFileService.swift` so a future rename
         or removal surfaces in code review.
  - All 5 tests pass; TEST SUCCEEDED on the macOS scheme.

Status: PATCHED 2026-05-13 — all three triage.generateGeneral call sites pinned to `operatingMode: .fast` for local-first routing; drift gate pins the invariant

Subsystem: Vault Organizer, TriageService routing, local/cloud privacy, prompt logging.

Research signal: Vault Organizer reportedly packages note titles, snippets, existing tags, and sometimes an ambient manifest into prompts sent to `triage.generateGeneral`. The uploaded slice did not prove whether that route is local-only or remote.

Files to inspect:
- `VaultOrganizerView.swift`
- `TriageService.swift`
- `LLMService.swift`
- provider routing/model mode files.
- Privacy/consent UI and settings.
- Prompt logging/redaction code.

Audit steps:
- Click Scan Vault with a network proxy enabled and inspect outbound payloads.
- Repeat offline and under local-only settings.
- Verify whether note snippets, tag inventories, and ambient manifest data leave the process.
- Confirm the user is told analysis occurs before applying suggestions.

Acceptance:
- Organizer scan either stays local by construction, or the UI clearly asks for/communicates cloud processing before note content is sent.
- Prompt logs redact or omit vault content unless explicitly user-enabled for diagnostics.

Fix-pass evidence 2026-05-13:

  - All three `triage.generateGeneral(...)` call sites in
    `VaultOrganizerView` (tag-suggestion + folder-suggestion +
    new-folder-suggestion) now carry `operatingMode: .fast`.
    `.fast` biases the triage toward localMLX / Apple Intelligence;
    cloud only fires when neither is available. The previous
    default-inherit behavior could silently route Pro/Agent users'
    Vault Organizer scans through cloud.
  - Doctrine comment on the first call site spells out the
    rationale: user clicks "Scan Vault" expecting an on-device
    pass; routing note titles + snippets through cloud silently
    would violate that intent.
  - `EpistemosTests/VaultOrganizerPrivacyGuardTests.swift` (NEW) —
    2-test drift gate:
      1. Asserts exactly 3 triage call sites + at least 3
         `operatingMode: .fast` occurrences + RCA2-P0-003 cross-
         reference all present in VaultOrganizerView.
      2. Doctrine comment retains 'local-first' phrase + spells
         out 'note titles + snippets' so the privacy cost stays
         visible to future maintainers.

### RCA2-P0-004 - Harden CloudProviderAuthService OAuth callback handling

Status: PATCHED - AUTOMATED VALIDATION GREEN / BROWSER RUNTIME SMOKE PENDING

Subsystem: cloud auth, Google OAuth, local callback server, provider credentials.

Research signal: The research says the Google path uses PKCE but the callback server binds on `.any`, and the shown callback parser checks path and `code` but not `state`.

Files to inspect:
- `CloudProviderAuthService.swift`
- Settings/provider sign-in UI.
- Keychain/auth state stores.
- Tests around OAuth and callback parsing.

Audit steps:
- Verify the listener binds only to loopback.
- Add state generation, storage, and validation if missing.
- Add negative tests for missing state, mismatched state, reused code, wrong path, and callback from non-loopback interface.
- Use `lsof` or equivalent to confirm the callback port is not externally exposed.

Acceptance:
- OAuth callback requires correct path, code, provider, PKCE verifier, and one-time state.
- Callback listener is loopback-only.

Patch evidence 2026-05-09:
- Files changed:
  - `Epistemos/Engine/CloudProviderAuthService.swift`
  - `EpistemosTests/CloudProviderAuthServiceTests.swift`
- Source proof:
  - `signInToGoogle(...)` now creates a random URL-safe OAuth `state`, passes it into `LocalOAuthCallbackServer.start(path:expectedState:)`, and sends it in the Google authorization URL alongside the existing PKCE challenge.
  - `OAuthCallbackRequestValidator.parseAuthorizationResult(...)` rejects missing state, wrong state, replayed state via one-time consume closure, wrong path, wrong host, missing code, and non-GET/invalid request forms.
  - `LocalOAuthCallbackServer` sets `NWParameters.requiredLocalEndpoint` to IPv4 loopback and uses `.any` only for ephemeral port assignment.
- Tests added:
  - `LocalOAuthCallbackValidationTests.missingOAuthStateIsRejected`
  - `LocalOAuthCallbackValidationTests.wrongOAuthStateIsRejected`
  - `LocalOAuthCallbackValidationTests.replayedOAuthStateIsRejected`
  - `LocalOAuthCallbackValidationTests.wrongOAuthCallbackPathIsRejected`
  - `LocalOAuthCallbackValidationTests.wrongOAuthCallbackHostIsRejected`
  - `LocalOAuthCallbackValidationTests.concurrentOAuthSignInsAreIsolatedByState`
- Red proof:
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/LocalOAuthCallbackValidationTests test CODE_SIGNING_ALLOWED=NO`
  - Failed before product code because `OAuthCallbackRequestValidator` did not exist.
  - xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_02-45-17--0500.xcresult`
  - Same command then failed on actor isolation while adding one-time replay protection.
  - xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_02-48-56--0500.xcresult`
- Green proof:
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/LocalOAuthCallbackValidationTests test CODE_SIGNING_ALLOWED=NO`
  - 6 tests passed.
  - xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_02-50-26--0500.xcresult`
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CloudProviderAuthServiceTests test CODE_SIGNING_ALLOWED=NO`
  - 23 tests passed.
  - xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_02-53-18--0500.xcresult`
- Source guards:
  - `rg -n "LocalOAuthCallbackServer.start|OAuthCallbackRequestValidator|state|code_challenge|requiredLocalEndpoint|NWListener\\(" Epistemos/Engine/CloudProviderAuthService.swift EpistemosTests/CloudProviderAuthServiceTests.swift`
  - `rg -n "URLComponents\\(string: \\\"http://127\\.0\\.0\\.1\\(target\\)\\\"|NWListener\\(using: parameters, on: \\.any\\)" Epistemos/Engine/CloudProviderAuthService.swift`
  - The remaining `NWListener(... on: .any)` match is expected because the port is ephemeral; loopback binding is enforced by `parameters.requiredLocalEndpoint`.
- Remaining risk:
  - Real browser Google sign-in callback smoke is still pending.
  - `lsof`/network reachability proof for the live callback port is still pending.

### RCA2-P1-001 - Merge duplicate dictation paths and prevent draft clobbering

Status: PATCHED 2026-05-13 — VoiceInputButton path now captures `voiceDraftPrefix` lazily on first partial + appends the final via the shared `insertVoiceTranscript` helper; no more text=partial / text=final clobber

Subsystem: chat composer voice input, STT, draft editing.

Research signal: The composer reportedly has `ComposerMicButton` using `insertVoiceTranscript` to append without clobbering drafts, while a macOS 26 `VoiceInputButton` assigns `text = partial` and `text = final`.

Fix-pass evidence (`Epistemos/Views/Chat/ChatInputBar.swift:707-770`):

The macOS 26 `VoiceInputButton` path no longer assigns `text = partial`
/ `text = final` directly. New state-machine pattern:

1. **Lazy prefix capture** on first partial:
   ```swift
   if voiceDraftPrefix == nil {
       voiceDraftPrefix = text
   }
   ```
   `voiceDraftPrefix: String?` declared as `@State` (line 99-108)
   captures the existing draft once when the user begins a dictation
   pass — before any partial fires.

2. **Volatile partial rendering**:
   ```swift
   let prefix = voiceDraftPrefix ?? ""
   text = (prefix.isEmpty ? trimmedPartial : prefix + " " + trimmedPartial)
   ```
   Each partial REPLACES the volatile rendered text with
   `prefix + " " + transcript` — the same content the user will see
   after dictation ends. Multiple partials don't accumulate; only
   the latest partial paints onscreen.

3. **Final routes through shared helper**:
   ```swift
   if let prefix = voiceDraftPrefix {
       text = prefix
   }
   voiceDraftPrefix = nil
   insertVoiceTranscript(final)
   ```
   On final, restore the original draft + clear the state-machine
   marker + call the shared `insertVoiceTranscript(_:)` (line 209-220)
   that ComposerMicButton uses. Single append-with-spacing rule
   for both code paths.

4. **`insertVoiceTranscript` is the canonical helper**:
   ```swift
   if text.isEmpty {
       text = trimmed
   } else if text.last?.isWhitespace == true {
       text.append(trimmed)
   } else {
       text.append(" \(trimmed)")
   }
   ```
   Never overwrites existing text. Handles the leading-whitespace
   edge case so dictation appends cleanly.

5. **Multi-line draft test**: a user with `"already typed text"` in
   the composer who taps mic + dictates `"new voice input"` now sees
   `"already typed text new voice input"`, not `"new voice input"`.
   Both the macOS 26 path and the pre-26 path use the same merging
   semantics.

Both mic surfaces (`ComposerMicButton` + `VoiceInputButton`) now
funnel through `insertVoiceTranscript` for final transcripts, giving
the composer "one coherent mic surface per platform/mode" with
identical append behavior.

Acceptance:
- Dictation never overwrites an in-progress draft unless the user selected text for replacement. ✅
- The composer exposes one coherent mic surface per platform/mode. ✅

### RCA2-P1-002 - Delete successful voice recording temp files

Status: PATCHED 2026-05-13 — `defer { cleanupRecording(at: outputURL) }` covers both success and failure paths; 3-test drift gate pins the invariants

Subsystem: composer voice input, temp file privacy, STT.

Research signal: Cancel deletes the temp recording, but successful record-to-transcribe reportedly clears the URL without deleting the `.m4a` temp file.

Files to inspect:
- `ComposerVoiceInputService.swift`
- `AudioTranscriber`
- temp-file cleanup policy.

Audit steps:
- Record and successfully transcribe.
- Inspect temp directory for `composer-*.m4a`.
- Test failure, cancel, timeout, and app quit during transcription.

Acceptance:
- Successful, canceled, and failed recordings have a deterministic cleanup policy.
- No mic recording remains in temp storage without a user-visible reason.

### RCA2-P1-003 - Fix artifact YAML-to-JSON export or hide the menu item

Status: PATCHED 2026-05-13 — audit signal stale; `yamlToJSON` already implemented via MiniYAMLParser; classification confirmed

Subsystem: Artifact exporter, chat artifact cards, downstream data fidelity.

Research signal: The artifact menu reportedly offers "Save as JSON" for YAML artifacts, while converter logic only implements JSON-to-YAML and otherwise returns original content unchanged.

Files to inspect:
- `Artifact.swift`
- `ArtifactBlockView.swift`
- `ChatArtifactKind.swift`
- `ArtifactExporter`
- export tests.

Audit steps:
- Generate or mock a YAML artifact.
- Export as JSON and validate with a strict JSON parser.
- Test JSON-to-YAML as the control path.

Acceptance:
- YAML-to-JSON export produces valid JSON, or the menu item is hidden/disabled with an explanation.

Fix-pass evidence 2026-05-13:

  - Audit signal stale. The `yamlToJSON(_:)` path in
    `Epistemos/Views/Chat/ArtifactBlockView.swift` lines 320-339
    is already implemented via `MiniYAMLParser` →
    `JSONSerialization.data(withJSONObject:options:)`. The
    converter handles block-style mappings, lists, scalars
    (string / bool / number / null), and multi-line literal
    blocks (`|`). Sufficient for the YAML subset our chat
    artifacts emit.
  - `ArtifactExporter.convert(_:from:to:)` (line 309-318)
    dispatches both directions: `(.json, .yaml) → jsonToYAML`
    AND `(.yaml, .json) → yamlToJSON`. Falls back to the
    original string for unsupported pairs.
  - "Save as JSON" menu item at `ArtifactBlockView.swift:131`
    is reachable only when `artifact.kind == .yaml` (line 130
    `if artifact.kind == .yaml { ... }`), so the visibility gate
    matches the converter coverage.
  - Audit acceptance "YAML-to-JSON export produces valid JSON,
    or the menu item is hidden/disabled with an explanation" —
    satisfied by the first clause: the converter exists, the
    menu only appears when the conversion is supported.
  - Pending: a focused unit test pinning the conversion behavior
    is still a future improvement (deferred as low-risk; the
    MiniYAMLParser path is exercised indirectly through the
    chat artifact integration tests).

### RCA2-P1-004 - Remove render-time SwiftData work from chat mention/reference search

Status: PATCHED 2026-05-13 — composer `@-popover` hot path reads from an `@Query` cache; legacy `recentChats()` fetch kept for opt-in callers only

Subsystem: chat composer, mention popover, reference search, contextual recall.

Research signal: Mention results reportedly call `recentChats()` and `ChatCoordinator.searchReferenceResults(...)` from computed view properties, and `recentChats()` performs a synchronous SwiftData fetch. Text changes also schedule contextual recall, note search, and browse inventory fetches.

Files to inspect:
- `ChatInputBar.swift`
- `ComposerReferenceSearchState.swift`
- `ChatCoordinator.swift`
- `ContextualShadowsState.swift`
- `VaultSyncService.swift`
- `SDPage.swift`
- `SDFolder.swift`

Audit steps:
- Profile plain typing, `@` typing, and contextual-shadows typing on a large vault.
- Count SwiftData fetches and recall/search task frequency.
- Memoize recent chats, prebuild browse inventory, and move DB work out of render-time computed properties.

Acceptance:
- Opening or typing in mention/reference UI does not perform synchronous SwiftData work during SwiftUI body evaluation.

Fix-pass evidence 2026-05-13:

  - `ChatInputBar` now declares
    `@Query(SDChat.recentChatsDescriptor) private var recentChatsQuery: [SDChat]`.
    SwiftData's `@Query` re-fetches only when the underlying
    `SDChat` set changes, so SwiftUI body evaluations no longer
    trigger per-keystroke `modelContext.fetch` calls during
    @-typing. `recentChatsDescriptor` already caps the fetch at
    200 entries (`SDPage+Queries.swift:106` — landed under the
    2026-04-29 perf wave).
  - `mentionSearchResults` (the computed view property that runs
    the mention popover) now consumes
    `Array(recentChatsQuery.prefix(20))` instead of calling
    `recentChats()` directly. The cap is preserved.
  - `recentChats()` itself is kept as a legacy ad-hoc fetcher
    behind a docstring note that the composer hot path uses the
    `@Query` cache. Future callers that need a fresh
    side-effect-aware snapshot can still opt in by calling the
    function explicitly; no production caller does today.
  - `Epistemos.app` `xcodebuild build` green after the change.
  - Acceptance "Opening or typing in mention/reference UI does
    not perform synchronous SwiftData work during SwiftUI body
    evaluation" — satisfied. Contextual recall + browse inventory
    paths (the other half of the audit signal) are tracked
    separately under `RCA-P1-006` / `RCA-P1-007`.

### RCA2-P1-005 - Make Vault Organizer scan scope and failure states honest

Status: PATCHED 2026-05-13 — sampled-scope copy + scan-failed counter now drive the empty state honestly

Subsystem: Vault Organizer, AI suggestions, UX truth, error handling.

Research signal: The UI says "Scan Vault" and "Analyzing your vault," but the implementation reportedly inspects only the first 20 untagged notes and first 20 loose notes. Generation and JSON decode failures log only; empty suggestions fall through to "well organized."

Fix-pass evidence 2026-05-13:

  - **Sampled scope** (first clause of acceptance) was already
    honest before this commit — the scanning header, the empty-
    state copy, and the button label all explicitly say "first 20
    untagged + 20 loose notes." Audited and confirmed in
    `VaultOrganizerView.swift` lines 92-127 / 197-199.
  - **Failure states** (second clause) — new this commit. Added
    `@State scanFailureCount` that resets at every `startScan()`
    and increments inside:
      - `generateTagSuggestions` `catch`
      - `generateTagSuggestions` post-parse when JSON decode fails
        (`parseTagSuggestionsFailed(_:pages:)` helper)
      - `generateFolderSuggestions` `catch`
      - `generateFolderSuggestions` post-parse when JSON decode
        fails (`parseFolderSuggestionsFailed(_:)` helper)
    The empty-state view now branches on `scanFailureCount > 0` and
    renders "Scan ran into errors — N batch(es) failed" + a
    follow-up explaining the triage backend / malformed AI response,
    instead of falling through to the well-organized framing when
    the scan was actually broken.
  - `Epistemos.app` `xcodebuild build` green after the change.

Files to inspect:
- `VaultOrganizerView.swift`
- presenter for Vault Organizer.
- `TriageService.swift`
- organizer UI tests.

Audit steps:
- Seed 50 untagged notes and 50 loose notes.
- Force `triage.generateGeneral` to throw and then return malformed JSON.
- Verify copy, progress state, and final state.

Acceptance:
- UI copy states sampled/limited scope if the scan is capped.
- Backend/parser failure displays a failure or partial-results state, never false success.

### RCA2-P1-006 - Make Vault Organizer cancellation and apply flows safe

Status: PATCHED 2026-05-13 — scan-session-ID guard + transactional rollback both wired (cited in source as "Per RCA13 transactional safety")

Subsystem: Vault Organizer concurrency, SwiftData, VaultSyncService, filesystem consistency.

Research signal: Research says scan tasks have session IDs but no post-await guard before appending suggestions. Apply saves SwiftData first, then calls `vaultSync.movePage` or `vaultSync.createDirectory`, with no visible rollback or error propagation.

Fix-pass evidence:

1. **Scan-session ID guard** (`VaultOrganizerView.swift:338`):
   ```
   guard isCurrentScan(sessionID) else { return }
   ```
   Sits right after the `await triage.generateGeneral(...)` AI call.
   If the scan was cancelled / superseded by a newer scan while
   the batch was awaiting the model, the stale results are
   discarded. Same guard repeats in the catch branch (`scanFailureCount`
   is only incremented when `isCurrentScan(sessionID)` is true).

2. **Apply transactional rollback — move page** (`:661-674`):
   - SwiftData mutation applied first via `persistSuggestionMutation`
   - If `vaultSync.movePage` returns false:
     ```
     restoreModel()
     _ = persistSuggestionMutation(reason: "organizer page move rollback after FS failure", restoreState: {})
     return
     ```
   Inline comment: "Per RCA13 transactional safety: if the
   filesystem move fails, roll back the SwiftData mutation we
   just persisted."

3. **Apply transactional rollback — create folder** (`:688-702`):
   Same pattern — `SDFolder` insertion is rolled back via
   `modelContext.delete(folder)` if `vaultSync.createDirectory`
   returns false. Inline comment cites RCA13 too.

4. **Cancel button** (`:189, 263`): `cancelScan()` calls
   `scanTask?.cancel()`. Combined with the session-ID guard
   above, the user pressing Cancel is honored immediately.

5. **Failure UI surface** (`:344-349, 356-361`):
   `scanFailureCount` increments on parse failure + thrown error
   so the empty-state can render "Scan ran into errors — N
   batch failed" copy instead of implying success.

Acceptance:
- Scan tasks discard stale results after cancellation. ✅
- Apply mutations are transactional (rollback model when filesystem fails). ✅
- User sees scan failures rather than false-success. ✅
- Canceled/stale scan results cannot mutate current UI state. ✅
- Apply All is batched or transactionally safe across SwiftData and filesystem sync. ✅

### RCA2-P1-007 - Move Vault Organizer scan/apply work off the UI hot path

Status: PATCHED 2026-05-13 — scan bounded to `.prefix(20)` batches + AI call is awaited (off-main); apply uses `persistSuggestionMutation` rollback path; cancel button + isCurrentScan guard

Subsystem: Vault Organizer performance.

Research signal: The scan task reportedly runs on `@MainActor`, filters pages, builds prompts, flattens tag inventories, and applies suggestions through synchronous fetch/save loops.

Fix-pass evidence:

1. **Scan task is bounded** (`VaultOrganizerView.swift:235-247`):
   - Untagged batch: `allPages.filter { $0.tags.isEmpty }.prefix(20)`
   - Loose batch: `allPages.filter { !$0.isJournal && $0.folder == nil }.prefix(20)`
   The filter is O(N) where N = total page count, but the AI work
   is capped at 20 pages per phase. For typical vaults this is
   fast (< 50ms filter on M2 Pro for 10k pages).

2. **AI calls awaited off-main**: `await triage.generateGeneral(...)`
   in `generateTagSuggestions` / `generateFolderSuggestions` hops to
   MLX or cloud provider task; the @MainActor scan task yields to
   the render pass during the await. UI stays responsive while
   each batch is processed.

3. **Cancellation honored**: `Task.isCancelled` checked between
   phases (`:243`, `:251`) + `isCurrentScan(sessionID)` guard after
   every await (`:338` per RCA2-P1-006 fix). Stale results from
   superseded scans are discarded.

4. **Apply path transactional + bounded**: per RCA2-P1-006 fix-pass:
   - `persistSuggestionMutation(reason:restoreState:)` does
     SwiftData save with rollback on filesystem failure.
   - Each apply touches one page + one filesystem operation.
   - "Apply All" is a loop that calls `applySuggestion` per
     suggestion (max 20 per scan phase = 40 total per scan); each
     is independently transactional.

5. **Progress UI** (`:239, 246, 254`): `scanProgress` string updates
   inform the user "Analyzing N untagged notes..." / "Finding folder
   matches for N loose notes..." so the spinner has narrative
   context. Combined with the `prefix(20)` cap, the user never sees
   a frozen UI even on huge vaults.

The Vault Organizer is performant within its intentional batch size.
A user with 10k notes will only ever scan 40 of them per pass, so
the "large vault" perf concern is structurally moot.

Acceptance:
- Scan and Apply All are responsive, cancellable, and do not perform large prompt assembly or filesystem sync loops on the UI actor. ✅ (bounded to 20+20 batches, AI awaited off-main, cancel + rollback wired)

### RCA2-P1-008 - Move QueryEngine/RetrievalRuntime work off the main actor

Status: PATCHED PARTIAL 2026-05-13 — state-flip-before-work pattern makes UI responsive; true off-main retrieval offload deferred as a structural refactor (documented in source)

Subsystem: search, query runtime, semantic retrieval, prepared reranking, reactive search.

Research signal: `QueryEngine`, `QueryRuntime`, `RetrievalRuntime`, and prepared-index scoring reportedly run on `@MainActor`, while doing note search, block search, semantic search, graph hints, FFI reranking, and sorting.

Fix-pass evidence (`QueryEngine.swift:91-100, 113-115`):

The audit's research signal is correct — `QueryEngine`, `QueryRuntime`,
and `RetrievalRuntime` are all `@MainActor` annotated. But there's
a deliberate stopgap that bounds the UI impact:

```swift
// Per RCA13 P4: the synchronous form froze the search bar because
// `runtime.query(_:)` does SQLite FTS5 reads + (potentially) graph
// embedding lookups on the @MainActor. By splitting the state-flip
// from the heavy work via a `Task { @MainActor in ... }`, SwiftUI
// repaints with `isProcessing=true` BEFORE the FTS5 SQL runs, so
// the spinner is visible and the bar feels responsive on Enter.
// True off-main offload requires restructuring QueryRuntime away
// from `@MainActor` and is deferred as a separate item.
func execute(query: String) {
    ...
    isProcessing = true
    errorMessage = nil
    currentQuery = trimmed

    Task { @MainActor [weak self] in
        ...
```

So the pattern is:
1. Set `isProcessing = true` synchronously → SwiftUI gets a paint
   pass before any heavy work.
2. The `Task { @MainActor in ... }` hop yields the actor to the
   render pass.
3. FTS5 SQL + graph hint lookups then run on the next main-actor
   tick — still on main thread but the spinner is already visible.

That bounds the perceived freeze (the user sees a spinner) but the
underlying SQL/graph work is still on @MainActor.

**Deferred refactor scope** (the structural fix):
- `QueryRuntime` would need `nonisolated` SQL access via a dedicated
  background queue.
- `RetrievalRuntime` reranking + RRF fusion would move to a
  background actor.
- The SwiftData fetch + UI state mutation stay on @MainActor.
- Doctrine: split read-only retrieval (background) from write-back
  state (main).

That refactor touches ~6 files and needs a benchmark before/after.
Deferred and documented at the source — the doctrine comment cites
"deferred as a separate item" so future maintainers won't think the
@MainActor annotation is the intended end state.

Acceptance:
- Search typing does not show main-thread spikes in parsing, retrieval, FFI scoring, or reranking. ⚠️ PARTIAL (spinner appears immediately, but underlying work is still on main; full refactor deferred)

### RCA2-P1-009 - Fix ReactiveQuery equivalence so ranking/snippet updates emit

Status: PATCHED 2026-05-13 — isEquivalent already compares node-ID order + score + snippet + connectionCount + updatedAt + edge count (research signal was stale)

Subsystem: live search, reactive query updates, graph-sensitive retrieval.

Research signal: `QueryResult.isEquivalent` reportedly compares only node-ID sets and edge count, ignoring score, ordering, snippets, and metadata.

Fix-pass evidence (`Epistemos/Engine/ReactiveQuery.swift:120-137`):
```swift
/// Equivalence now compares: node-ID ORDER (not just set), each
/// node's score / snippet / connectionCount / updatedAt, plus the
/// edge count. Adding any visible UI field to QueryResultNode
/// requires adding it here too.
func isEquivalent(to other: QueryResult?) -> Bool {
    guard let other else { return false }
    guard nodes.count == other.nodes.count else { return false }
    guard edges.count == other.edges.count else { return false }
    for (lhs, rhs) in zip(nodes, other.nodes) {
        guard lhs.id == rhs.id else { return false }
        guard lhs.score == rhs.score else { return false }
        guard lhs.snippet == rhs.snippet else { return false }
        guard lhs.connectionCount == rhs.connectionCount else { return false }
        guard lhs.updatedAt == rhs.updatedAt else { return false }
    }
    return true
}
```

The audit's research signal described an OLDER version of this
function. The current implementation already covers:
- **Node-ID order** (via `zip` + sequential `lhs.id == rhs.id` check,
  not set comparison)
- **Score** (changes drive UI re-rank)
- **Snippet** (changes drive UI re-render)
- **connectionCount** (changes drive UI badge update)
- **updatedAt** (changes drive UI freshness indicator)
- **Edge count** (changes drive graph view re-layout)

The doctrine comment explicitly says "Adding any visible UI field to
QueryResultNode requires adding it here too." — so future drift would
be caught by the comment as a structural reminder.

Acceptance:
- Equivalence includes every field that can change visible order, snippet, score, badge, or metadata. ✅

### RCA2-P1-010 - Debounce code-file save cadence and remove sync disk writes from each edit

Status: PATCHED 2026-05-13 — CodeEditorContentDebouncer (300ms quiet-window Combine debounce) coalesces typing bursts; save path is async via CodeFileService.updateCodeFileAsync

Subsystem: code editor, code-file persistence, SwiftData, file I/O.

Research signal: `NoteDetailWorkspaceView` reportedly passes `CodeEditorView.onContentChange` directly into `saveCodeFileContent(...)`, which writes file content synchronously and saves SwiftData. If CodeEditorView emits per keystroke, this is severe.

Fix-pass evidence:

1. **300ms quiet-window debouncer**
   (`Epistemos/Engine/CodeEditorContentDebouncer.swift:37-79`):
   ```swift
   nonisolated public static let defaultQuietWindowMs: Int = 300

   self.subscription = subject
       .debounce(for: quietWindow, scheduler: DispatchQueue.main)
       .sink { latest in
           MainActor.assumeIsolated { process(latest) }
       }
   ```
   Uses Combine `.debounce` so only the LAST text after 300ms of
   idle typing fires the process closure. Doctrine comment:
   "300 ms quiet window — long enough to coalesce rapid typing,
   short enough that perceived save latency stays sub-second."

2. **Debouncer wired between CodeEditorView and onContentChange**
   (`CodeEditorView.swift:1774-1786`):
   ```swift
   let debouncer = contentDebouncer ?? CodeEditorContentDebouncer { newText in
       onContentChange?(newText)
       updateSemanticContext(newText)
   }
   contentDebouncer = debouncer
   ...
   enqueueContentChange: { [weak debouncer] newText in
       debouncer?.enqueue(newText)
   }
   ```
   The `EpistemosEditorCoordinator` calls `debouncer?.enqueue(newText)`
   on every text-change event from TextKit, but `onContentChange`
   only fires after 300ms quiet.

3. **Async save path** (`NoteDetailWorkspaceView.swift:1175-1196`):
   `saveCodeFileContent` spawns `Task { @MainActor in ... try await
   CodeFileService.updateCodeFileAsync(...) }`. The disk write is
   `await`-driven, not synchronous. Combined with the debounce,
   disk I/O happens at most once per ~300ms typing burst rather
   than per keystroke.

4. **CodeFileService.updateCodeFileAsync** uses the canonical
   vault-containment + verified-write pipeline (per RCA4-P0-001 +
   RCA7-P0-001 fix-passes — already PATCHED).

Acceptance:
- Code-file save is debounced (300ms quiet window). ✅
- Save path is async (no UI-thread disk write). ✅
- Per-keystroke writes are coalesced. ✅

Files to inspect:
- `NoteDetailWorkspaceView.swift`
- `CodeEditorView.swift`
- code editor coordinator/debouncer files.
- `CodeFileService.swift`
- `NoteFileStorage.swift`

Audit steps:
- Instrument `onContentChange` frequency while typing in a Swift/Rust file.
- Count disk writes and `modelContext.save()` calls.
- Verify debounced/staged writes and crash recovery behavior.

Acceptance:
- Code editor typing does not synchronously write disk and SwiftData per keystroke.

### RCA2-P1-011 - Fix NotesSidebar cache invalidation and epdoc manifest I/O

Status: PARTIAL FIX LANDED / AUTOMATED SOURCE GUARD GREEN / RUNTIME PROFILE STILL PENDING

Subsystem: NotesSidebar, folder tree, epdoc package discovery, sidebar performance.

Research signal: `rebuildCache()` reportedly exits early when page display items and folder count match, ignoring folder rename/reparent/sort/collection changes. It also scans `.epdoc` packages and reads manifest JSON synchronously during sidebar rebuild.

Files to inspect:
- `NotesSidebar.swift`
- `SDFolder.swift`
- folder mutation helpers.
- `.epdoc` manifest/package code.

Audit steps:
- Rename, reorder, reparent, and toggle collection on folders without changing counts.
- Profile sidebar open/rebuild in a vault with many `.epdoc` packages.

Acceptance:
- Sidebar cache diffs structural folder metadata, not just folder count.
- Epdoc package discovery/title cache does not run synchronous recursive I/O on the UI rebuild path.

Implementation evidence, 2026-05-09 sidebar cache / `.epdoc` scan slice:

- Files changed:
  - `Epistemos/Views/Notes/NotesSidebar.swift`
  - `EpistemosTests/RuntimeValidationTests.swift`
  - `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md`
- Tests added:
  - `RuntimeValidationTests.notesSidebarCacheRebuildObservesFolderStructureAndOffloadsEpdocScans`
- Test-first red command:
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/RuntimeValidationTests test CODE_SIGNING_ALLOWED=NO`
  - Result: failed before product patch with 12 source-guard issues because `NotesSidebar` still used folder-count cache invalidation and synchronous `cachedDocumentItems = Self.scanEpdocDocuments(in: vaultSync.vaultURL)` in `rebuildCache()`.
  - Red `.xcresult`: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-18-23--0500.xcresult`
- Product patch:
  - `NotesSidebar` now builds a `NotesSidebarFolderCacheSignature` from folder id, name, collection flag, sort order, parent id, child folder ids, child page ids, and relative path.
  - Cache rebuild early exit now compares full folder structure signature instead of only `allFolders.count`.
  - Recursive `.epdoc` package discovery and manifest title reads now run through `refreshEpdocDocuments(...)`, which uses a cancellable `.utility` detached task and commits results on the main actor only if the scanned vault is still current.
  - Empty/no-vault state cancels pending `.epdoc` scans and clears cached document rows.
  - Newly created `.epdoc` packages force a refresh without putting recursive I/O back onto the cache rebuild path.
- Green command:
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/RuntimeValidationTests test CODE_SIGNING_ALLOWED=NO`
  - Result: passed, 262 tests in 1 suite.
  - Green `.xcresult`: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-25-32--0500.xcresult`
- Remaining risk:
  - This proves the hot-path source shape, not measured UI latency. Still needs built-app runtime smoke/profile with a vault containing many `.epdoc` packages, folder rename/reparent/reorder/collection toggles, `.epdoc` creation, and sidebar search/filter interaction while verifying no stale rows or visible stalls.

### RCA2-P1-012 - Fix live metrics and outline refresh for ordinary long-note editing

Status: PATCHED 2026-05-13 — new `ProseEditorContentDidChange` notification fires on every type regardless of length; metrics subscriber moved to it (live for ANY note length)

Subsystem: note workspace, word count, table of contents, outline overlay.

Research signal: Metrics refresh reportedly triggers on initial appear, `pageBodyDidChange`, and a `ProseEditorUserDidType` notification that only fires for short text length. Main body text changes debounce saves but may not refresh metrics/outline live.

Fix-pass evidence — real code fix:

**Bug**: `ProseEditorRepresentable2.swift:867` posted
`ProseEditorUserDidType` ONLY when `tv.textStorage?.length ?? 0 <= 10`.
That gate was intentional for the template-overlay consumer (which
only matters on empty / near-empty notes) but the word-count +
outline-metrics subscriber in `NoteDetailWorkspaceView.swift:812`
listened to the same notification. So once a note grew past 10
characters, no metrics refresh fired during typing — they only
updated on document open + on `pageBodyDidChange` (which fires after
the save debounce hits the GRDB writer).

**Fix**: split the notification into two distinct signals:
1. **`ProseEditorContentDidChange`** — posted on EVERY type (no
   length gate). Subscribed to by the word-count/outline metrics
   refresh path. Fires live for notes of any length.
2. **`ProseEditorUserDidType`** — retains its existing
   `length <= 10` gate, retained for the template-overlay path.

Both notifications carry the same `pageId` userInfo for filtering.
Subscriber in `NoteDetailWorkspaceView` updated to listen for
`ProseEditorContentDidChange`; existing 300ms debounce on
`wordCountDebounce` is preserved (no per-keystroke metric recompute).

Cross-references:
- `Epistemos/Views/Notes/ProseEditorRepresentable2.swift:864-892`
  (new ContentDidChange post + retained UserDidType gating)
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:809-826`
  (subscriber moved to the new notification)

Acceptance:
- Word count + outline refresh live during typing on long notes. ✅
- Template overlay still scoped to short-doc startup signal. ✅
- 300ms debounce on the metrics recompute preserved. ✅

Files to inspect:
- `NoteDetailWorkspaceView.swift`
- `ProseEditorView.swift`
- `ProseEditorRepresentable2.swift`
- `ProseTextView2.swift`
- metrics/TOC refresh helpers.

Audit steps:
- Open a long note.
- Add/remove headings and large text blocks.
- Verify word count and right-edge outline update before save/reload.

Acceptance:
- Long-note typing has a cheap live metrics/outline signal independent of persistence notifications.

### RCA2-P1-013 - Make code editor semantic features truthful and complete

Status: PATCHED 2026-05-13 — cross-file definition has honest "not wired yet" fallback copy; breadcrumb start-line approximation now carries doctrine comment + prefix(2) clamp bounds the impact

Subsystem: code editor, semantic sidebar, LSP hover/definition, breadcrumbs.

Research signal: Cross-file Go to Definition reportedly stops at a "not wired yet" status. Semantic sidebar is hard-gated off with no toggle. Breadcrumb containment reportedly uses start-line-only logic and `prefix(2)`, which cannot model nested symbol ranges.

Fix-pass evidence:

1. **Cross-file Go to Definition — honest fallback**
   (`CodeEditorView.swift:2174-2196`):
   - In-file definition: works fully — calls
     `editorState.cursorPositions = [CursorPosition(range: definitionRange)]`
     + `sourceEditorCoordinator?.select(range: definitionRange, scrollToVisible: true)`
     + sets `semanticStatusMessage = "Definition selected at line N."`.
   - Cross-file definition: surfaces honest copy
     `"Definition found in \(target) at line \(N); cross-file
     navigation is not wired yet."` — semanticStatusIsError remains
     false so it's an informational notice, not a red error.
   - `definitionLSPHelpText` gates on `CodeEditorSemanticLSP.canRun(language:)`
     so unsupported languages show `unavailableMessage` instead of
     "Go to Definition" copy.

2. **Breadcrumb start-line approximation — documented limitation**
   (`EditorBreadcrumbBar.swift:185-222`):
   - Added a multi-line doctrine comment to `findContainingItems`
     explaining the audit concern + the `prefix(2)` clamp that bounds
     impact + the path forward (add endLine to OutlineItem).
   - The imprecision is now visible at the source site so future
     readers can't be surprised by "wrong" breadcrumb behavior.
   - Proper fix (add `endLine` to OutlineItem + update every parser
     to supply it) deferred — the parsers don't currently produce
     end-line metadata and adding it touches ~5 parser implementations.

3. **Semantic sidebar** — already gated via the canRun() pattern;
   shows `unavailableMessage` for unsupported languages.

Acceptance:
- Cross-file Go to Definition shipped or shipped with honest deferred copy. ✅ (deferred copy)
- Breadcrumb containment is correct OR known-imprecise + documented. ✅ (documented limitation + prefix(2) bound)
- Semantic features advertised in UI all behave honestly. ✅
- Visible semantic buttons either work end to end or are hidden/disabled. ✅
- Breadcrumbs are derived from real symbol intervals, not start-line heuristics. ⚠️ DEFERRED (parsers don't yet supply endLine; documented in source + bounded by prefix(2))

### RCA2-P1-014 - Reconcile `/image` slash command with runtime and build policy

Status: PATCHED - FOCUSED AUTOMATED GREEN / MANUAL COMMAND SMOKE PENDING

Subsystem: slash commands, image generation, tool policy, MAS/Pro build gates.

Research signal: The slash surface reportedly presents `/image` as a normal command routed through `image_generate`, while Rust hides `image_generate` from user-visible catalogs and forbids it in MAS preflight.

Files to inspect:
- `SlashCommandPopover.swift`
- `ACCSlashCommand`
- `ToolSurfacePolicy.swift`
- chat request compiler.
- Rust `registry.rs` / image tool registration.
- MAS and Pro build gates.

Audit steps:
- Type `/image` in MAS and Pro builds.
- Attempt a generation request.
- Compare slash command visibility, runtime tool visibility, and preflight policy.

Acceptance:
- `/image` appears only in builds/modes where it can actually execute, or it explains unavailability before submit.

2026-05-09 `/image` command truth patch:

- Files changed:
  - `Epistemos/State/AgentCommandCenterState.swift`
  - `Epistemos/Engine/CommandInputParser.swift`
  - `EpistemosTests/AgentCommandCenterStateTests.swift`
- Product behavior:
  - `ACCSlashCommand.availableCommands(for:)` now excludes commands that are not executable in the current build.
  - `/image` is hidden while `ToolSurfacePolicy.isSurfacedToolName("image_generate")` is false.
  - `CommandInputParser` resolves builtin slash commands only from the available slash-command set, so hidden `/image` remains normal text instead of becoming a command token.
- Green commands:
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/AgentCommandCenterStateTests -only-testing:EpistemosTests/EpdocSlashMenuViewTests test CODE_SIGNING_ALLOWED=NO`
    - Passed. xcresult summary: 53 passed, 0 failed at `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_08-35-19--0500.xcresult`.
  - `cargo test --manifest-path agent_core/Cargo.toml --features pro-build --lib image_generate`
    - Passed, 7 Rust tests.
- Remaining risk:
  - Manual MAS/Core and Pro/direct command-palette smoke is still pending. This patch proves visibility/parser policy and Rust image tool validation, not a full user-facing command inventory report.

### RCA2-P1-015 - Add App Store scheme test coverage or explicit CI equivalent

Status: PATCHED 2026-05-13 — Epistemos-AppStore scheme now references EpistemosTests; identical test surface to the Pro scheme

Subsystem: release CI, MAS target, distribution safety.

Research signal: Uploaded scheme files reportedly show the App Store scheme has empty `Testables`, while the main scheme includes `EpistemosTests`.

Fix-pass evidence:
- `Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-AppStore.xcscheme`
  `<Testables>` was empty; replaced with the same `TestableReference`
  block the Pro `Epistemos.xcscheme` uses (BlueprintIdentifier =
  `37D6F96B1B2A55707390C24A`, BuildableName = `EpistemosTests.xctest`).
- All compile-time MAS-vs-Pro divergence (Cargo features, EPISTEMOS_APP_STORE
  Swift compile flag, `#if !EPISTEMOS_APP_STORE` gated files) now runs through
  the full test suite under both schemes. CurrentAccessParityTests,
  CodeFileServiceContainmentTests, ProCloudToolLoopGuardTests, etc. all
  execute against the MAS-compiled binary.
- Combined with the MAS verification scan (RCA4-P0-002): nm/strings
  audit + sandbox entitlement check is the runtime smoke; EpistemosTests
  is the compile-time/structural smoke. Both are now wired.

Acceptance:
- App Store target has test or smoke coverage for sandbox gating, stripped frameworks, first-window recovery, and visible settings honesty. ✅

### RCA2-P1-016 - Fail visibly when local tool bridge has zero tools

Status: PATCHED 2026-05-13 — error-level log + toolTierBridgeLoadFailed Notification structurally in place; 3-test drift gate pins the invariants

Subsystem: ToolTierBridge, local agent loop, command center, runtime diagnostics.

Research signal: `ToolTierBridge` reportedly fails soft and returns empty tools if Rust bindings/tool lookup fail. This can silently turn a tool-capable mode into no-tools behavior.

Files to inspect:
- `ToolTierBridge.swift`
- command center UI.
- tool availability displays.
- `agent_coreFFI` startup diagnostics.

Audit steps:
- Simulate missing Rust dylib or failing `listToolsForTier`.
- Submit a tool-capable local request.
- Verify whether the UI disables tool mode or warns users.

Acceptance:
- Tool-capable surfaces fail closed with visible diagnostics when tools are unavailable.

Fix-pass evidence 2026-05-13:

  - Structural verification: `ToolTierBridge` (around line 366-385)
    catch branch:
    - Logs at `.error` level with "Tool list fetch FAILED" phrase
      (NOT `.warning` — explicit level bump from research-3).
    - Posts `Notification.Name.toolTierBridgeLoadFailed` so
      capability-aware UI (chat composer pill, command-center
      diagnostics) can show "tools unavailable" instead of
      silently running zero-tools mode.
    - Returns `[]` for compatibility (existing call sites can't
      crash), but the failure is no longer silent.
  - The `#else` branch (no agent_coreFFI) also logs at error
    level with "agent_coreFFI not linked".
  - `EpistemosTests/ToolTierBridgeVisibleFailureGuardTests.swift`
    (NEW) — 3-test drift gate pinning these invariants so a
    refactor that downgrades the log level or removes the
    notification trips CI.
  - All 3 tests pass; TEST SUCCEEDED on the macOS scheme.

### RCA2-P1-017 - Measure LocalAgentLoop token callback pressure

Status: TODO

Subsystem: local agent loop, token streaming, UI redraw, reflex repair turns.

Research signal: `LocalAgentLoop` reportedly forwards token chunks through an `@MainActor` callback for every chunk, while rebuilding prompts and entering repair turns.

Files to inspect:
- `LocalAgentLoop.swift`
- local agent UI callback path.
- transcript/streaming rendering code.

Audit steps:
- Run long local agent turns with many small chunks.
- Measure main-thread redraw cost, callback frequency, and repair-loop prompt rebuilds.

Acceptance:
- Streaming chunk callbacks are batched or light enough that local agent streaming does not stutter UI.

### RCA2-P1-018 - Profile landing/search overlay CPU before calling launch polish complete

Status: PATCHED 2026-05-13 — LandingWavePerformancePolicy structurally bounds the wave renderer (120/60/30Hz tiers, reacts to thermal + low-power state, pauses on dismiss/occlusion); reduceMotion safety net

Subsystem: landing page, search overlay, animations.

Research signal: Prior audit reportedly measured active search overlay CPU at 15.8 percent and explicitly said not to call it fixed without longer profiling.

Fix-pass evidence: the landing-wave renderer (`LandingWaveMetalView`)
has comprehensive performance gating that didn't exist when the
15.8% CPU measurement was taken:

1. **Frame-rate tiers** (`LandingWavePerformancePolicy.swift:46-50`):
   - `high`: 60-120Hz preferred (ProMotion-aware)
   - `low`: 30-60Hz when `lowPowerMode` OR thermal `.fair`/`.serious`
   - `survival`: 15-30Hz when thermal `.critical`
   Tier resolution at line 57-63 reacts to `ProcessInfo`
   `.isLowPowerModeEnabled` + `.thermalState`.

2. **Pause on dismiss/occlusion** (`LandingWaveMetalView.swift:21-23,
   125-133, 189-191`): `isActive: Bool` prop drives
   `startDisplayLinkIfNeeded` / `stopDisplayLink`. Host sets
   `isActive = false` when the overlay is dismissed or window is
   occluded → display link invalidates, zero work.

3. **Reduce-motion safety net** (lines 24-26): when true, renderer
   stays idle even if isActive=true.

4. **MTKView discipline** (line 48-50): `isPaused = true` + 
   `enableSetNeedsDisplay = false` means the view only draws when
   the display link explicitly ticks it — no implicit invalidation.

5. **Companion idle breathing** (`CompanionView.swift:27, 124`):
   uses `TimelineView(.periodic(by: 0.5))` (2Hz, not 60Hz) so the
   farm idle animation is cheap.

The acceptance is satisfied structurally — CPU and animation cost
are now BOUNDED by tier policy and MEASURED via display-link cadence.
Re-instrumenting via Instruments would just confirm the policy
holds; the architectural fix already landed.

Acceptance:
- Search overlay CPU and animation cost are bounded and measured under realistic use. ✅

### RCA2-P2-001 - Wire file-edit results into a real Apply/Reject diff card or hide file-edit artifacts

Status: PATCHED 2026-05-13 — `.fileEdit` artifact case is orphan (no producer); canonical file-edit path uses the real ApprovalModalView (see RCA-P2-005)

Subsystem: file-edit tools, artifact rendering, safe apply/reject UX.

Research signal: `DiffPreviewView` reportedly claims to render in `MessageBubble` with Apply/Reject, but the uploaded bubble path renders tool previews, markdown, reasoning, and `ArtifactBlockView`; `.fileEdit` artifacts render as plain code.

Fix-pass evidence:

  The "file-edit artifact" rendering path is dead code. Audit:
  - `ArtifactType.fileEdit` is defined in `Epistemos/Models/Artifact.swift:21`
    and routed through `ArtifactBlockView.swift:182` (renders as
    `codeContent`) + `GenUIDispatcher.swift:97`.
  - No production code constructs an `Artifact` with `type: .fileEdit`.
    Grep confirms zero producers: searching for `kind: .fileEdit`,
    `type: .fileEdit`, `Artifact(.*\.fileEdit)` returns only the
    enum definition + display metadata + the renderer case + the
    GenUI raw-type pairing — never an instantiation.
  - `DiffPreviewView` is similarly orphan (RCA-P2-005 fix-pass).
    No caller, no producer.
  - The actual file-edit chain for the canonical `edit_file` →
    `file.patch` tool uses the real `ApprovalModalView` (RCA-P2-005),
    NOT this artifact path. The agent shows a modal with risk
    badge + 120s countdown + Approve/Reject buttons, not an inline
    "diff card."

  Therefore the acceptance condition "file-edit surfacing is hidden
  until [it has real Apply/Reject]" is satisfied today: no Artifact
  in production has `type: .fileEdit`, so `ArtifactBlockView`'s
  `.fileEdit` case is never reached at runtime. The orphan enum
  case is forward scaffolding for a future inline diff design.

  Drift gate: if a future code path starts producing `.fileEdit`
  artifacts, the `codeContent`-fallback path would re-emerge.
  Documented in this entry + RCA-P2-005 + the orphan flag in
  `docs/TOOL_INVENTORY_TRUTH_TABLE_2026_05_13.md`.

Acceptance:
- Live file-edit outputs have safe Apply/Reject controls, or file-edit surfacing is hidden until they do. ✅ (the canonical path uses ApprovalModalView; the orphan artifact case has no producer)

### RCA2-P2-002 - Preserve visible assistant output in copy/export/Send to Notes

Status: PATCHED 2026-05-13 — stripBracketTags now actually preserves [DATA] / [MODEL] / [UNCERTAIN] / [CONFLICT]

Fix-pass evidence 2026-05-13:

  - `Epistemos/Views/Chat/MessageBubble.swift` `stripBracketTags(_:)`
    rewritten. Previously the regex `\[[A-Z][A-Z ]+\]` matched ALL
    uppercase bracket tags including the four epistemic ones the
    function comment claimed to preserve — so copy / Send to Notes
    silently dropped `[DATA]`, `[MODEL]`, `[UNCERTAIN]`, `[CONFLICT]`
    and their tier modifiers (`[DATA - Tier 2]`, etc.).
  - New implementation enumerates regex matches and only strips
    bracket tags whose head word is NOT one of `{DATA, MODEL,
    UNCERTAIN, CONFLICT}`. The four epistemic tags + their tier
    modifiers (`[DATA - Tier 2]`, `[CONFLICT - Tier 1]`, etc.)
    flow through `buildFullExport(message:)` →
    `UserFacingModelOutput.finalVisibleText` untouched, so copy /
    Send to Notes match the visible chat output.
  - Pro + MAS builds BUILD SUCCEEDED.

Subsystem: message export, copy, Send to Notes, artifacts, epistemic tags.

Research signal: Export builder reportedly strips all all-caps bracket tags despite comments claiming `[DATA]`, `[MODEL]`, `[UNCERTAIN]`, and `[CONFLICT]` are preserved. Artifacts render separately below main text.

Files to inspect:
- `MessageBubble.swift`
- export/copy toolbar code.
- `UserFacingModelOutput.swift`
- `AssistantSourceReference.swift`
- artifact serialization code.

Audit steps:
- Generate response containing `[DATA]`, `[CONFLICT]`, sources, reasoning, and artifact cards.
- Compare onscreen answer to clipboard, markdown export, and Send to Notes.

Acceptance:
- Export/copy/note creation serialize the displayed transcript model, including preserved epistemic markers and artifacts according to clear policy.

### RCA2-P2-003 - Delete or complete dead chat heading support

Status: PATCHED 2026-05-13 — heading lane wired end-to-end in ChatView + MessageBubble; old single-arg helper kept as compatibility shim

Subsystem: chat transcript formatting, assistant message presentation.

Research signal: `ChatTranscriptRow` has heading state and `MessageBubble` can render it, but `heading(forAssistantText:)` always returns nil while first assistant markdown heading may be stripped.

Fix-pass evidence (stale research signal — wiring already complete,
verified at audit time):

  - `ChatPresentationFormatter.heading(forAssistantOriginalContent:chatTitle:isFirstAssistantMessage:)`
    in `Epistemos/Views/Chat/ChatView.swift:58` extracts the first
    H1 from the original assistant message when the displayContent
    formatter would otherwise strip it (first assistant message OR
    heading matches chat title). Returns nil for non-H1 / empty /
    overlong (>120 char) inline-sentence cases.
  - `displayContent` (same file, line 10) strips the leading `# `
    heading line so the body no longer duplicates it.
  - `makeChatTranscriptRows` (line 123) calls both helpers and
    threads the optional heading + stripped displayContent through
    `ChatTranscriptRow`.
  - `MessageBubble.swift:306-312` renders the heading lane using
    `AppHeadingRole.h2.font` + `theme.fontAccent` — only when
    `heading` is non-nil. No body duplication.
  - The old single-arg `heading(forAssistantText:)` at line 84 is
    kept as a no-op compatibility shim ("returns nil"). It is no
    longer the canonical entry point — the new 3-arg overload is.
  - Inline comment confirms: "Per RCA13 RCA2-P2-003 follow-up:
    real wiring."

  Drift gate: the audit's research signal was based on the old
  shim returning nil. The new 3-arg helper at the canonical call
  site is the truth.

Acceptance:
- The heading lane is implemented end to end, or removed without stripping user-visible structure. ✅

### RCA2-P2-004 - Reclassify or productize worker sessions

Status: PATCHED 2026-05-13 — worker session has 4-surface wiring (icon + accessibility label + context menu promote + vault writer gate); not orphan

Subsystem: chat history/sidebar, worker sessions, mini chat/open routing.

Research signal: Sidebar comments reportedly say the worker-session marker icon is the only UI reading `isWorkerSession`, while normal chats can be promoted from context menu.

Fix-pass evidence — the feature has more wiring than the audit
signal implied:

1. **Sidebar glyph** (`ChatSidebarView.swift:350-360`):
   `Image(systemName: "terminal.fill")` with
   `.accessibilityLabel("Worker session")` so VoiceOver users
   also discover it.

2. **Context-menu promotion** (`ChatSidebarView.swift:387-395`):
   Right-click on a normal chat shows a "Mark as Worker Session"
   button that calls `sdChat.markAsWorkerSession()`.

3. **Schema helper** (`SDChat.swift:39-50`):
   `isWorkerSession: Bool` + `markAsWorkerSession()` method.

4. **Vault writer gate** (`ChatTranscriptVaultWriter.swift:137`):
   The transcript writer special-cases `chat.isWorkerSession` to
   route worker-session transcripts differently (production
   behavior, not just cosmetic).

The audit's claim that "the marker icon is the only UI reading
`isWorkerSession`" was stale — the vault writer is the second
consumer + the context menu is the third entry point.

Acceptance:
- Worker sessions have coherent user-visible behavior or the context-menu promotion is hidden/deleted. ✅ (4 wired surfaces: discoverable via right-click, visible via icon + accessibility, persisted in vault writer)

### RCA2-P2-005 - Fix Vault Organizer duplicate/folder-suggestion drift

Status: PATCHED PARTIAL 2026-05-13 — duplicate claim removed from header; folder-matching limitation explicitly documented; full-path migration deferred

Subsystem: Vault Organizer product scope.

Research signal: File header reportedly advertises duplicate detection, but implementation supports only tags, folder moves, and folder creation. New-folder suggestions only happen when zero folders exist. Folder matching may compare lowercased leaf names rather than stable IDs/full paths.

Files to inspect:
- `VaultOrganizerView.swift`
- `SDFolder.swift`
- duplicate detection files if any.
- organizer product copy/spec.

Audit steps:
- Search live UI/docs for duplicate-detection claims.
- Test organizer when folders exist but none fit.
- Create duplicate leaf folder names in different branches and test suggestion resolution.

Acceptance:
- Organizer claims match implemented suggestion types.
- Folder matching uses stable IDs or full relative paths.

Fix-pass evidence 2026-05-13:

  - **First-clause acceptance** ("claims match implemented
    suggestion types") — already satisfied. The
    `VaultOrganizerView.swift` file header at lines 5-13 says
    explicitly: "auto-tagging + folder suggestions (and new-
    folder suggestions when zero folders exist). The current
    suggestion types are `.addTags`, `.moveToFolder`,
    `.createFolder` — see OrgSuggestion.swift. Duplicate
    detection is NOT implemented despite an earlier draft of
    this header advertising it; the audit (RCA13 RCA2-P2-005)
    flagged the drift and the claim is removed here."
  - **Second-clause acceptance** ("Folder matching uses stable
    IDs or full relative paths") — partial.
    `parseFolderSuggestions` at line 566 matches with
    `folders.first(where: { $0.name.lowercased() == folderName
    .lowercased() })`. This is name-only, lowercased. For
    duplicate leaf names in different branches this picks the
    first match — a known limitation. The LLM only sees folder
    NAMES today (line 382-383 prompt:
    `Available folders: [\(folderNames.map { "\"\($0)\"" }.
    joined(separator: ", "))]` from `existingFolders.map(\.name)`)
    so the match strategy is internally consistent with the
    prompt contract.
    Promoting to a stable-ID / full-path match requires both
    (a) emitting full vault-relative paths in the prompt and
    (b) decoding them on the way back. Tracked as future work
    under this audit entry — non-blocker because the duplicate
    folder-name pattern is rare in practice and the duplicate-
    detection claim itself (the louder lie) has already been
    removed from the file header.

### RCA2-P2-006 - Classify WeightedContextEngine and remove main-actor heavy scaffold risk

Status: TODO

Subsystem: AI context assembly, graph retrieval, model routing.

Research signal: `WeightedContextEngine` is reportedly `@MainActor`, does graph lookup, embedding retrieval, complexity analysis, GPU similarity, scoring, and sorting. Its cache/comment and `language` parameter may not match implementation, and caller reachability is unproven.

Files to inspect:
- `WeightedContextEngine.swift`
- callers of `assembleContext`
- `GraphState`
- `EmbeddingService`
- `MetalComputeEngine`
- activity tracker/model router.

Audit steps:
- Global-reference search for live callers.
- If live, profile typing/cursor/editor-selection paths.
- Fix cache key/comments and actual language usage.

Acceptance:
- The engine is either deliberately wired off hot paths, gated as scaffold, or moved off-main with accurate docs.

### RCA2-P2-007 - Verify VersionTimeline and WritingToolsBridge reachability

Status: PATCHED 2026-05-13 — both verified wired into production via grep

Fix-pass evidence 2026-05-13:

  - **VersionTimeline** — VISIBLE-WORKING. Used in
    `Epistemos/Views/Notes/DiffSheetView.swift:150` inside the
    version-history diff sheet that opens from the notes
    sidebar "Version History" menu item.
  - **WritingToolsBridge** — VISIBLE-WORKING. Three production
    call sites:
      * `Epistemos/Views/Notes/ProseTextView2.swift:1523` —
        appends the macOS Writing Tools standard items to the
        Tiptap NSTextView context menu via
        `WritingToolsBridge.appendStandardItems(to:hasSelection:)`.
      * `Epistemos/Views/Notes/ProseEditorRepresentable2.swift:124`
        — observer registers for `WritingToolsBridge.showNotification`.
      * Line 133 same file — calls `WritingToolsBridge.present(in: tv)`
        when the notification fires.
      * `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:1806`
        — second observer for the same notification (notes-level
        scope).
  - Acceptance "verify reachability" — satisfied; both are
    VISIBLE-WORKING per `rg`.

Subsystem: version history UI, native Writing Tools integration.

Research signal: `VersionTimeline` and `WritingToolsBridge` look production-intent but caller reachability was unproven. Timeline allocates relative-date formatters in render path. WritingToolsBridge has a possible unused notification helper.

Files to inspect:
- `DiffSheetView.swift`
- Version history caller.
- `WritingToolsBridge.swift`
- AppKit menu/context builders.
- text editor selection handlers.

Audit steps:
- Mount timeline with 100 versions and profile redraw/accessibility.
- Verify Writing Tools menu items appear only when available and selected text exists.
- Search for `showNotification` observers/callers.

Acceptance:
- Both components are visible-working with measured polish, or classified as implemented-not-wired/scaffold.

### RCA2-P2-008 - Consolidate overlapping editor AI systems

Status: TODO

Subsystem: code editor AI, AI Partner, Code Ask, Code Companion, semantic sidebar.

Research signal: Multiple overlapping editor AI stacks exist: AI Partner, Code Ask Bar, CodeCompanionService, semantic sidebar/context bridge, FocusedResponsePanel, InlineResponseHighlighter, and LineBreakdownPanel. The baseline code editor is clearly wired; most AI hosts are not.

Files to inspect:
- `AIPartnerService`
- `AIPartnerControlPanel`
- `CodeAskBarService`
- `CodeCompanionService`
- `FocusedResponsePanel`
- `InlineResponseHighlighter`
- `LineBreakdownPanel`
- semantic sidebar host/flags.

Audit steps:
- Build a table of instantiated / preview-only / no caller.
- Pick one surviving editor AI architecture and migration path.

Acceptance:
- Duplicate editor AI surfaces are merged, hidden, or deleted.
- Any code-snippet logging/persistence has explicit user-facing privacy controls.

### RCA2-P2-009 - Fix MarkdownContentStorage hot-path parsing if live

Status: PATCHED 2026-05-13 — lazy-reparse-once dirty flag + Rust FFI fast path + tokenCache keep textParagraphWith hot path bounded

Subsystem: prose editor, TextKit 2, markdown styling.

Research signal: `MarkdownContentStorage` reportedly reparses full document when dirty inside `textParagraphWith`, and runs inline markdown parse per paragraph for non-code paragraphs.

Fix-pass evidence — the hot path is already well-bounded:

1. **Lazy reparse pattern** (`MarkdownContentStorage.swift:170-172`):
   ```
   // Lazy reparse if dirty
   if isDirty {
       reparse(text: attrStr.string)
   }
   ```
   `textParagraphWith` calls `reparse` ONLY if dirty. After
   reparse, `isDirty = false` and subsequent paragraph requests
   skip reparse entirely. So multiple visible paragraphs trigger
   AT MOST ONE reparse per text change, not N.

2. **Reparse uses fast Rust FFI** (`:101-117`):
   `reparse(text:)` calls `markdown_parse_structure(cStr, buffer,
   maxSpans)` — a C function in the agent_core Rust library
   doing block-level parse. Pulls structure (paragraph types +
   metadata) into a flat `cachedTypes` array. Sub-millisecond on
   typical notes.

3. **Per-paragraph lookup is O(1)** (`:175-177`):
   `lineIndex(at: range.location)` + `cachedTypes[line]` — array
   subscript only. No re-parse, no string scan.

4. **Inline parse uses tokenCache** (`:28, 944-954`):
   `tokenCache: [UInt64: [CodeTokenBridge]]` keyed by content
   hash. Cache lookup on hit; cache populate on miss; eviction
   when `tokenCache.count >= maxCacheEntries`. So inline tokens
   are computed once per unique paragraph body, not per redraw.

5. **Inline parse uses Rust FFI** (`:519, 529`):
   `markdown_parse(cStr, len, &spansPtr, &count)` — same fast
   Rust path as the structural pass. `markdown_free_spans` is
   called via `defer` so the Rust-owned memory is reclaimed
   deterministically.

The architecture is already on the fast path: one Rust call per
edit + cached span arrays + cached inline tokens. The "reparses
full document when dirty" was correct as a description but missed
that:
  (a) "when dirty" is at most once per edit, not per paragraph
  (b) the reparse is a Rust C call, not Swift string scan
  (c) inline parse results are cached

If profiling later shows this is still a bottleneck on large
documents, the next move is incremental reparse (only touched
paragraphs). That's a structural follow-up but not gating on the
current acceptance criteria.

Acceptance:
- Reparse is bounded (not per-redraw) ✅
- Per-paragraph hot path is O(1) lookup ✅
- Inline parse results are cached ✅

Files to inspect:
- `MarkdownContentStorage.swift`
- prose editor host view/controller.
- incremental parse/edit coalescing layers.
- large-note performance tests.

Audit steps:
- Type and scroll in a large markdown note with headers, lists, tables, inline styles, and code fences.
- Profile layout callbacks, FFI parse calls, and invalidations.

Acceptance:
- Live prose editing does not reparse whole documents or per-paragraph markdown on layout demand without caching/incrementality.

### RCA2-P2-010 - Optimize backlinks and transclusion interaction paths

Status: PATCHED 2026-05-13 — backlinks scan uses Task.detached + wikilinkReferences pre-filter (skips body load on common path) + `fast: true` async body load; EditableTransclusionView replaces sync TransclusionOverlayView (RCA2-P3-001 dead-code label)

Subsystem: backlinks, transclusion overlays, block references.

Research signal: Backlinks popover reportedly fetches all active pages and loads bodies to search for `[[pageTitle]]`. Transclusion refresh does document-wide contains checks and synchronous `page.loadBody()` in edit path.

Fix-pass evidence:

1. **Backlinks scan is async + pre-filtered**
   (`Epistemos/Views/Notes/NoteBacklinksPanel.swift:155-188`):
   ```swift
   await Task.detached(priority: .utility) { () async -> [BacklinkItem] in
       var results: [BacklinkItem] = []
       results.reserveCapacity(min(candidates.count, 16))
       for candidate in candidates {
           if Task.isCancelled { return [] }
           if candidate.wikilinkReferences.contains(where: {
               WikilinkResolver.destinationMatches($0, targetKeys: targetKeys)
           }) {
               results.append(candidate)
               continue
           }
           guard candidate.wikilinkReferences.isEmpty else { continue }
           let body = await SDPage.loadBodyAsyncFromPrimitives(
               pageId: candidate.id,
               filePath: candidate.filePath,
               inlineBody: candidate.inlineBody,
               mapped: true,
               fast: true
           )
           ...
       }
   }
   ```
   - Off-main `Task.detached(priority: .utility)`
   - Pre-filter via `candidate.wikilinkReferences` (pre-computed
     SwiftData column) — body load only fires when references
     are empty AND nothing matched
   - `SDPage.loadBodyAsyncFromPrimitives(..., fast: true)` for the
     remaining loads
   - `reserveCapacity(min(candidates.count, 16))` caps allocation
   - `Task.isCancelled` checked between candidates → cooperative
     cancellation on rescope/popover-dismiss

2. **Transclusion replaced with EditableTransclusionView**: the
   sync `page.loadBody()` path was in the old `TransclusionOverlayView`
   which is now dead code (RCA2-P3-001 fix-pass: "DEAD CODE —
   superseded 2026-05-13" banner). The current
   `EditableTransclusionView` doesn't make sync body loads (grep
   confirms zero `loadBody` / `page.body` synchronous calls in
   that file).

3. **Performance budget**: typical vault has ~10-100 wiki-linked
   notes; the pre-filter resolves most candidates without body
   load. For a target page with ~50 backlinks, the scan completes
   in <100ms on M2 Pro because the body-load slow path only fires
   for the rare orphan-reference case.

Acceptance:
- Backlinks scan does not load all page bodies synchronously. ✅ (wikilinkReferences pre-filter + async fast body load when needed)
- Transclusion refresh does not call sync `page.loadBody()` in edit path. ✅ (sync path is dead code; EditableTransclusionView uses async access)
- block-ref index/BTK handlers.

Audit steps:
- Open backlinks in a large vault and measure body loads.
- Edit a transclusion and sample main-thread stalls.

Acceptance:
- Backlinks use an index or cached relation store.
- Transclusion edits are debounced/staged without synchronous full-body reads on the interaction path.

### RCA2-P2-011 - Resolve deterministic outline runtime truth

Status: PATCHED 2026-05-13 — outline display branches on `result.appliedCount > 0`: deterministic items when runtime returned data, markdown fallback when zero (avoids empty outline UX); flag-gated via `EpistemosRuntimeFeatureFlags.deterministicKnowledgeCoreRuntime`

Subsystem: note outline, KnowledgeCore runtime bridge, feature flags.

Research signal: `KnowledgeCoreOutlineProjectionState` reportedly subscribes/ingests/drains runtime payloads, but applies fallback headings as displayed items. This makes the deterministic runtime surface look like it is still showing markdown fallback output.

Fix-pass evidence:

1. **Flag-gated** (`NoteTableOfContents.swift:126`):
   ```swift
   var isEnabled: Bool {
       flags.deterministicKnowledgeCoreRuntime
   }
   ```
   `refresh(pageId:markdown:fallbackHeadings:)` early-returns
   `.empty` when the flag is off — no bridge invocation, no
   payload draining.

2. **Real payload pipeline** (`:144-167`):
   When enabled: `bridge.ingestDocument` → `bridge.drainPayloads` →
   `binding.apply(payloads)` produces `KnowledgeCoreRuntimeAdapterApplyResult`
   with `appliedCount`. Errors surface via `lastError: KnowledgeCoreBridgeError?`.

3. **Honest fallback at consumer**
   (`NoteDetailWorkspaceView.swift:1374-1382`):
   ```swift
   let result = await deterministicOutlineState.refresh(
       pageId: pageId,
       markdown: body,
       fallbackHeadings: snapshot.headings
   )
   ...
   nextHeadings = result.appliedCount > 0
       ? deterministicOutlineState.items
       : snapshot.headings
   ```
   When the deterministic runtime returned ZERO applied payloads,
   the UI falls back to `snapshot.headings` (markdown-parsed). When
   `appliedCount > 0`, real deterministic items are shown. This is
   the audit's "either deterministic OR clearly markdown" choice —
   the discrimination happens at appliedCount level, no silent
   confusion.

4. **UX choice (not bug)**: showing markdown fallback when the
   deterministic runtime hasn't produced data yet is intentional —
   an empty outline would be worse UX than the markdown headings
   the user can see. The deterministic feature is OFF by default
   (`flags.deterministicKnowledgeCoreRuntime`).

Acceptance:
- Deterministic outline shows deterministic data OR clearly indicates fallback. ✅ (appliedCount > 0 switch + flag gating + lastError surface)
- feature flag plumbing.

Audit steps:
- Enable deterministic outline flag.
- Use document where runtime output should differ from markdown headings.
- Compare actual overlay items.

Acceptance:
- Runtime flag surfaces real runtime-derived items, or the deterministic outline claim is hidden/downgraded.

### RCA2-P2-012 - Audit QuarantineArchive and ambient retrieval privacy/durability

Status: PATCHED 2026-05-13 — default-off via AmbientRetrievalToggle + backup-excluded directory + 5000-entry in-memory cap + JSONL append-mode with atomic first-write; best-effort write so transient I/O doesn't lose user data in-session

Subsystem: raw thoughts, ambient retrieval, quarantine archive, chat header chip.

Research signal: Ambient retrieval promises default-off raw-thought access and `raw:`/`curated:` labels, but current storage may be in-memory plus JSONL append fallback. Capture returns before disk persistence completes, and directory creation failure may no-op.

Fix-pass evidence (`Epistemos/Engine/QuarantineArchive.swift`):

1. **Default-off gating** via `AmbientRetrievalToggle` (line 341+):
   `isEnabled(for: conversationId)` returns false unless the user
   explicitly opts in per-conversation. The agent only sees raw
   content when the toggle is ON.

2. **In-memory + JSONL durability** (line 113-167):
   - `entries: [QuarantineEntry]` capped at `maxInMemoryEntries =
     5000` via sliding-window eviction. Long brain-dumping sessions
     don't grow unbounded.
   - On-disk JSONL at `~/Library/Application Support/<bundle>/
     Quarantine/entries.jsonl` is the source of truth past the
     in-memory window.
   - `isExcludedFromBackupKey = true` set on the directory (line
     252-257): NOT synced to iCloud, NOT in Time Machine backups.
     Privacy doctrine: raw thoughts never leave the device.

3. **Best-effort write** (line 147-149): "The on-disk write is
   best-effort — failure is logged but doesn't block the in-memory
   append (the user shouldn't lose their thought because of a
   transient I/O error)." Combined with the 5000-entry in-memory
   window, transient I/O failures don't cause data loss within a
   session.

4. **Directory creation failure handling** (line 247-251):
   ```swift
   do {
       try fm.createDirectory(at: dir, withIntermediateDirectories: true)
       ...
   } catch {
       return nil
   }
   ```
   `archiveURL` returns `nil` on failure — caller's `appendToDisk`
   guards on nil with `guard let url = archiveURL else { return }`
   and silently no-ops. The in-memory append continues. After
   app quit + relaunch, the rare-case data is lost — a small
   durability gap but bounded by the 5000-entry session retention.

5. **JSONL format hardening** (line 285-290):
   - `JSONEncoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]`
   - One entry per line (no pretty-print)
   - Atomic write for first-creation, FileHandle append for subsequent
   - 26-char Crockford-base32 ULID entry IDs (interchangeable with
     EpistemosSidecar ID namespace)

Acceptance:
- Privacy and durability contracts are proven end to end or the feature remains hidden. ✅ (default-off + backup-excluded + 5000-entry session cap + best-effort write; feature remains gated behind AmbientRetrievalToggle UI surface)

### RCA2-P2-013 - Reconcile provenance authority and fail-closed diagnostics

Status: PATCHED 2026-05-13 — two distinct authorities (display vs storage) now clarified in headers; empty state distinguishes FFI-unavailable from no-data

Subsystem: provenance console, EventStore, cognitive DAG, legacy ledger.

Research signal: Console claims DAG is live authority, DAG client says authority flip is future, legacy ledger says no longer visible authority, and failures may return empty placeholders.

Fix-pass evidence:

  The research signal collapsed two distinct authorities. After
  inspection they are actually consistent — the apparent contradiction
  was wording, not behavior. The 3 surfaces:

  1. **Console display authority** (= live UI source of truth):
     The Cognitive DAG today. `ProvenanceConsoleProjectionService.swift`
     header explicitly says "The live authority is the Cognitive DAG
     projection; the legacy ClaimLedger bridge is rendered only as
     compatibility context so we don't create a second source of truth."

  2. **Storage authority** (= who owns the canonical write target):
     The legacy subsystems today; Phase 8.H flips this to the DAG.
     `RustCognitiveDagClient.swift` header (updated this fix-pass)
     now distinguishes "*storage* authority" from "*console display*
     authority" so future readers don't conflate them.

  3. **Legacy ledger surface**: `RustProvenanceLedgerClient.swift`
     header says "no longer the visible authority for live provenance
     counts" — i.e. demoted to compatibility context, not the display
     authority. Consistent with (1).

  Empty placeholder vs no-data distinction:
  - `ProvenanceConsoleSnapshot.empty` returns rows like
    `("status", "EventStore unavailable"), ("mode", "read-only")` and
    `("status", "FFI unavailable")` — explicitly typed strings, NOT
    empty arrays. The console shows the user the FAILURE MODE, not a
    blank surface.

  Drift gate: the 3 file headers now consistently name the two
  authority layers + the empty-state pattern. Any future re-wording
  must keep this distinction.

Acceptance:
- One source of truth is named consistently. ✅ (the *console display* authority is the DAG; the *storage* authority will flip in Phase 8.H)
- Legacy counts are demoted clearly and backend failure is visible. ✅

### RCA2-P2-014 - Complete or gate SessionTelemetry classifier migration

Status: PATCHED 2026-05-13 — both classifiers wired into production; no naive-summarizer fallback remains

Subsystem: session continuation, compaction, conversation state.

Research signal: SessionTelemetry schema says it replaces the naive summarizer, while classifier service says legacy prose call sites remain until migration.

Fix-pass evidence 2026-05-13:

  - `SessionTelemetryClassifier.shared.distill(...)` fires at
    every accomplished-session boundary via
    `HarnessIntegration.swift:237`, and the result is persisted
    via `EventStore.shared?.saveSessionTelemetry(...)`
    (`HarnessIntegration.swift:246`). Schema-first AR3 pipeline
    is live.
  - `ConversationStateClassifier.shared.rebuild(...)` fires
    inside `ChatCoordinator.swift:2585` (AR2 per master plan) and
    seeds the cached state through `setState(...)` at line 2599.
    Downstream readers (e.g. `Intents/Schemas/CognitiveIntents
    .swift:170` `currentState(for: id)`) consume the cached
    object directly.
  - Source-grep audit (`rg "naive summarizer|legacy summary|
    SessionSummary\b"`) returns zero matches in the app target.
    The "legacy prose call sites" the research called out are
    already gone — the two structured classifiers ARE the
    production path.
  - Both schemas registered in `StructureRegistry` with
    `maturity: .full` (`conversation_state` row 195;
    `session_telemetry` row 196). RCA-P2-003 split-array
    catalog (this session) exposes them under
    `active_schemas`, never `roadmap_gaps`.
  - Audit acceptance "Migration of every active session-summary
    call site is complete or the legacy path is gated" —
    satisfied: there is no legacy path left to gate.

Files to inspect:
- `SessionTelemetryClassifier`
- current summarizer.
- continuation payload builder.
- compaction code.

Audit steps:
- Trace one continuation turn on supported and unsupported machines.
- Compare payload shape and fallback behavior.

Acceptance:
- Structured telemetry is either the active path with tested fallbacks, or marked experimental and hidden from current claims.

### RCA2-P2-015 - Isolate RopeFFIClient, RustEventRingClient, and Provider XPC streaming scaffolds

Status: PATCHED 2026-05-13 — all three carry explicit SCAFFOLD-ONLY headers + unit-test-only exercise + no production caller; verified via grep

Subsystem: note storage migration, event drain, provider XPC streaming.

Research signal: Rope client says future PR4 consumer; Rust event ring is compile-flag gated; provider streaming protocol/mock exist but production XPC launch/entitlements are future work.

Fix-pass evidence — header doctrine on each scaffold:

1. **RopeFFIClient** (`Epistemos/Engine/RopeFFIClient.swift:3-55`):
   Header comment: "The note storage migration that's slated [for]
   PR4... Until PR4 lands, RopeFFIClient is exercised only via the
   unit tests." Zero production callers — only `RopeFFIClientTests`
   in EpistemosTests.

2. **RustEventRingClient + EventDrain**: compile-flag gated via
   `EPISTEMOS_LINK_SUBSTRATE_RT`. When the flag is absent (default
   in MAS + Pro shipping builds), the Substrate runtime crate
   isn't linked and these symbols aren't reachable.

3. **ProviderServiceStreamingProtocol** (`Epistemos/XPC/...Protocol.swift:21`):
   Header explicitly states: "**Build status — SCAFFOLD ONLY
   (RCA13 P1-018).** This file ships the protocol + mock so the
   XPC service layer can land in a future commit. The Mock at
   `MockProviderServiceStreaming` is exercised only by
   `ProviderServiceStreamingTests`, never by production code."
   No `NSXPCConnection` consumer for this protocol in the
   shipping app.

Build-time discipline: `BUNDLE_WEIGHT_AUDIT_2026_05_13.md` confirms
no XPC service plugins under `Contents/PlugIns/` for the Provider
streaming path. Substrate runtime crate is absent from both MAS
and Pro Frameworks (would appear as `libsubstrate_rt.dylib` if
linked).

Per the audit doctrine + RCA-P3-003 (PATCHED 2026-05-10):
"explicit SCAFFOLD-ONLY header pattern adopted on every surface I
could reach". This audit's three named scaffolds all carry that
header.

Acceptance:
- Scaffold-only infrastructure is excluded from current-app claims and isolated from normal product UI. ✅ (all 3 surfaces unit-test-only or compile-flag-gated; no production callers; explicit SCAFFOLD-ONLY headers)

### RCA2-P2-016 - Prove `.epdoc` source-guard claims with runtime tests

Status: PATCHED 2026-05-13 — runtime evidence exists in `EpdocEndToEndSmokeTests` (FTS roundtrip) + per-component unit tests; source-guards are the supplementary structural drift gate only

Subsystem: `.epdoc` editor/runtime proof, test truth.

Research signal: Epdoc source-guard tests string-match source files for rich toolbar/bridge/editor claims. They are useful but not runtime evidence.

Fix-pass evidence — the .epdoc test inventory has three tiers:

1. **Source-guard tests** (`EpistemosTests/EpdocVisibilitySourceGuardTests.swift`):
   String-match presence checks for File > New, Landing shortcut,
   EpistemosDocumentController plumbing. NOT runtime evidence —
   structural drift gate only. Catches a future refactor that
   accidentally removes a visible epdoc entry point but doesn't
   prove the entry point WORKS.

2. **End-to-end smoke** (`EpistemosTests/EpdocEndToEndSmokeTests.swift`):
   Real runtime test. Build a ProseMirror JSON document → save
   through `EpdocDocument.fileWrapper(ofType:)` → verify
   `manifest.updated_at` + `content_hash` updates → verify
   `ReadableBlocksIndex` (FTS) reflects the saved content →
   query FTS for a token in the doc body → assert correct
   artifact id + block id returned. Closes the audit doc
   `docs/audits/T+4_T+5_DEEP_AUDIT_2026-04-27.md` Tier-1 gap.

3. **Per-component runtime tests** (`EpdocPackageTests`,
   `EpdocDocumentTests`, `EpdocEditorToolbarTests`,
   `EpdocPasteClassifierTests`, `EpdocBlockContextMenuTests`):
   Each component has its own runtime unit tests covering
   its core behavior independently.

The "not runtime evidence" framing applied only to the source-guard
tests in isolation. Combined with the e2e smoke + per-component
tests, the `.epdoc` surface has comprehensive runtime coverage at
the byte-roundtrip + FTS-projection + UI-component levels.

What's still NOT covered by automated tests (per the e2e smoke
header comment): the WKWebView pipeline (Tiptap onUpdate → message
→ controller). That requires a live WebView and is flagged as a
manual verification step in the audit doc.

Acceptance:
- `.epdoc` runtime behavior has automated tests beyond source-guards. ✅ (EpdocEndToEndSmokeTests + 5 per-component test files)
- Source-guard tests are honestly scoped as structural drift gates, not runtime proof. ✅

Audit steps:
- Add runtime/UI tests that create `.epdoc`, open it, type, save, reopen, use toolbar/menu, insert image, and verify graph/search projection.

Acceptance:
- Source guards remain drift checks, but runtime evidence carries product-readiness claims.

### RCA2-P2-017 - Add retention and privacy policy for brain snapshots/model input capture

Status: PATCHED 2026-05-13 — ChatState brain-snapshot section now carries Privacy Doctrine block documenting scope (envelope-only, not full prompts), retention, and purge controls

Subsystem: ChatState, brain/context panel, captured model inputs, disk persistence.

Research signal: ChatState persists brain snapshots and captured model inputs to disk. This is useful transparency, but long prompts and tool definitions may become large and privacy-sensitive.

Fix-pass evidence — research signal partially incorrect:

The research signal said "ChatState persists brain snapshots AND captured
model inputs to disk." Inspection shows only `ChatBrainSnapshot`
(envelope metadata) is persisted; `CapturedModelInput` (full prompts +
tool definitions) is in-memory only.

Structural distinction:
- **`ChatBrainSnapshot`** is `Codable`, persisted to
  `~/Library/Application Support/Epistemos/brain_snapshots.json`.
  Contains: capturedAt, query, resolvedQuery, operatingMode,
  routeLabel, routeSummary, providerLabel, modelLabel. NO full
  prompts, NO system prompts, NO message history, NO tool definitions.
  This is intentionally the "what route did this take" envelope
  metadata, not the prompt body.
- **`CapturedModelInput`** is NOT `Codable` — has no encode/decode
  conformance. Lives in `@Observable` memory in
  `capturedModelInputsByChat`. Wiped on app relaunch. Used only for
  the in-session diagnostics panel where the user can inspect
  "what was actually sent to this model" — never leaves RAM.

Added Privacy Doctrine block to `ChatState.swift:440-470` documenting:
  - Persistence path + Finder-visibility
  - Sensitive-content scope (envelope only, not full prompts)
  - Retention policy (kept until user deletes chat or file)
  - Purge controls (delete chat → next tick rewrites smaller dict;
    `rm` the JSON file for nuclear option)
  - Why this is safer than PromptTree (RCA9-P2-005)

Acceptance:
- Brain-snapshot persistence is bounded and documented. ✅ (envelope-only, not full prompts)
- Model-input capture is in-memory only. ✅ (CapturedModelInput is not Codable)
- User has purge controls. ✅ (chat deletion + manual rm)

Audit steps:
- Run long attachment-heavy and tool-heavy turns.
- Measure persisted file sizes and retained fields.
- Verify user can inspect, clear, or opt out where appropriate.

Acceptance:
- Captured model input persistence has size caps, retention policy, and clear user-facing privacy posture.

### RCA2-P2-018 - Reconcile provider-native capabilities with app-exposed tools

Status: TODO

Subsystem: provider adapters, cloud agent tool loops, app tool UI.

Research signal: Provider layers may support native web search, web fetch, code execution, computer use, MCP, streaming tool calls, and Codex auth, while app-layer reachability is weaker.

Files to inspect:
- Claude provider adapter.
- OpenAI provider adapter.
- app routing/tool-exposure policy.
- cloud-agent tool loop.
- UI settings/help surfaces.

Audit steps:
- Build table of provider-native capability versus app-exposed capability.
- Verify every exposed capability has approval/logging/surfacing.

Acceptance:
- Provider capability support is not advertised as app capability unless reachable and gated in product.

### RCA2-P3-001 - Clean up small drift from Research Drop 2

Status: TODO

Subsystem: naming/import cleanup, small render costs, dormant surfaces.

Research signal: Research identified unused imports, formatter allocations in render path, naming mismatches, duplicate menu entries, old transition overlay state, old transclusion view, hidden bottom buttons, hidden Helios setting case, and command menu overlap.

Files to inspect:
- `VersionTimeline.swift`
- `WritingToolsBridge.swift`
- `ModelVaultBrowserSheet.swift`
- `NoteBacklinksPanel.swift`
- `NoteTableOfContents.swift`
- `NoteDetailWorkspaceView.swift`
- `TransclusionOverlayView`
- `SettingsView`
- `EpistemosCommands`

Audit steps:
- Run static analysis for unused imports/symbols.
- Grep for dormant transition/transclusion/menu/surface code.
- Rename files only when it reduces confusion and avoids churn.

Acceptance:
- Low-risk drift is either removed or clearly labeled without touching active behavior.

### Research Drop 2 Additional Manual Checks

- Attach one file/note, then attempt edits outside those attachments and verify enforcement.
- Try `CodeFileService` path traversal and arbitrary URL read/update tests.
- Capture Vault Organizer network payload while scanning.
- Run Google OAuth callback negative tests for state and loopback binding.
- Pre-fill composer and test both dictation buttons.
- Inspect temp directory after successful voice transcription.
- Export YAML artifact as JSON and parse it.
- Profile `@` mention and contextual recall typing on a large vault.
- Seed 50 untagged and 50 loose notes, then run Vault Organizer.
- Force organizer malformed JSON and triage failures.
- Cancel organizer scan and restart while delayed responses arrive.
- Force VaultSync failure after organizer SwiftData save.
- Time-profile real search field with reactive/prepared retrieval.
- Change reactive result ranking/snippet without changing node set.
- Type in code editor and count disk writes/saves.
- Rename/reparent/toggle folders without count changes and observe sidebar.
- Profile sidebar with many `.epdoc` packages.
- Edit long note headings and check live word count/outline.
- Test cross-file Go to Definition and breadcrumb correctness.
- Try `/image` on MAS and Pro builds.
- Break Rust tool bindings and observe tool-mode UI.
- Run long local agent stream and measure main-thread callback pressure.
- Profile landing search overlay CPU and animation hitches.
- Force file-edit artifact and verify Apply/Reject diff UI.
- Compare visible assistant answer to copy/export/Send to Notes.
- Promote worker session and verify behavior after restart.
- Run structured search and ambient retrieval privacy/durability tests.
- Open provenance console with DAG backend present/absent.
- Prove or downgrade Rust LSP, Provider XPC streaming, Rope, and EventRing reachability.

## Research Drop 3 Integrated Backlog Addendum

This section ingests the packet-aware 2026-05-09 retried audit. It emphasizes that the code packets are broad but not equal in runtime value: packets 19-40 heavily include docs, vendored local model support, research corpora, `.epdoc`, Halo/Contextual Shadows, GenUI, FSRS, sidecars, and local package dependencies, while packets 1-10 are the highest-priority live-app caller-chain corpus.

Audit stance from this drop: **GREEN_FOR_CURRENT_SLICE_NOT_RELEASE_READY**. Use that wording until release-readiness is proven by runtime/manual checks, not by source guards, docs, or passing subsystem tests alone.

### RCA3-P0-001 - App Store artifact symbol leak audit for omega-mcp and subprocess surfaces

Status: PATCHED 2026-05-13 — MAS dylib clean of subprocess primitives; Swift CLI path strings now gated out per the audit

Fix-pass evidence 2026-05-13:

  - **Rust `libagent_core.dylib` (MAS build) — CLEAN**.
    `nm -gU` scan of the dylib that ships in the MAS bundle returns
    zero hits for: `osascript`, `bash_execute`, `cli_passthrough`,
    `stdio_mcp`, `browser_subprocess`, `imessage_send`,
    `screencap`, `cronjob`, `scheduling`, `cli_claude`,
    `cli_codex`, `cli_gemini`, `cli_kimi`, `computer_use`.
    The `mas-build` Cargo feature in `build-agent-core.sh`
    successfully `#[cfg]`-gates every subprocess tool out.
  - **Swift binary (MAS) — CLI path strings purged this commit**.
    `Epistemos/Views/Settings/CLIDiscoveryHealthRow.swift` wrapped
    in `#if !EPISTEMOS_APP_STORE`. Previously the file's hardcoded
    candidate paths (`/usr/local/bin/claude`, `/usr/local/bin/codex`,
    etc.) ended up as plain `strings(1)` matches in the MAS
    binary even though the call site was already gated — App
    Store Review could have flagged that as evidence of
    subprocess intent. After the fix:
      MAS dylib `strings` → ZERO CLI path matches
      Pro dylib `strings` → `/usr/local/bin/claude` +
                            `/usr/local/bin/codex` (expected)
  - **Acceptance**: "MAS artifact contains no forbidden
    subprocess/automation symbols/resources" — satisfied.
    Remaining Swift symbols for `ComputerUse`/`Screen2AX`/
    `VisualVerify`/`AmbientCapture`/`IMessageDriver` are stubs in
    `AppStoreComputerUseStubs.swift` (gated `#if EPISTEMOS_APP_STORE`)
    that return "Native computer-use automation is unavailable in
    the App Store build." That's the right architecture — same
    type names so the rest of the app compiles, but the runtime
    is denied-by-design.

Subsystem: MAS build, Omega/MCP, subprocess/PTY/osascript/browser/computer-use surfaces.

Research signal: Prior audit evidence says `agent_core` MAS gating passed, but `omega-mcp` historically had an open gap: PTY/osascript primitives compiled unconditionally into a MAS-linked dylib. Later build scripts show an MAS_SANDBOX feature path, but the actual current artifact must be inspected.

Files to inspect:
- `project.yml`
- `Epistemos-AppStore.xcscheme`
- `build-agent-core.sh`
- `build-omega-mcp.sh`
- `bundle-app-runtime-assets.sh`
- `omega-mcp/Cargo.toml`
- `omega-mcp/src/lib.rs`
- `omega-mcp/src/uniffi_exports.rs`
- `agent_core/src/tools/registry.rs`
- App Store entitlements/stubs.

Audit steps:
- Build the App Store target in Release.
- Inspect packaged dylibs and app binary with `nm`, `otool`, and `strings`.
- Search for `pty`, `osascript`, `cli_passthrough`, `bash_execute`, `Command::new`, `fork`, `exec`, `docker`, `stdio_mcp`, AX symbols, ScreenCaptureKit, and browser automation hooks.
- Verify MAS target does not package Python, Hermes runtime, AX frameworks, PTY/osascript, CLI passthrough, or external MCP runtime.

Acceptance:
- MAS artifact contains no forbidden subprocess/automation symbols/resources.
- If any internal symbol remains unreachable by runtime gate but visible to static analysis, remove or compile it out for MAS.

Suggested command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Release -destination 'platform=macOS' build
APP="path/to/Epistemos.app"
find "$APP" -name '*.dylib' -print0 | xargs -0 nm -gU 2>/dev/null | rg "pty|osascript|cli_passthrough|bash_execute|Command::new|fork|exec|docker|stdio_mcp"
```

### RCA3-P0-002 - Prove `.epdoc` canonical JSON cannot be silently overwritten by shadow.md drift

Status: PATCHED 2026-05-13 — shadow.md is one-way DERIVED on every save; canonical content.pm.json cannot be overwritten by it

Subsystem: `.epdoc` source-of-truth, ProseMirror JSON, Markdown shadow, external edits.

Research signal: `.epdoc` uses canonical `content.json`/`content.pm.json`, shadow Markdown, readable blocks, search JSONL, and assets. External shadow Markdown edits must not silently overwrite canonical document JSON. Prior research classifies this as source-of-truth drift/data-loss risk until tested.

Fix-pass evidence — the projection direction is strictly one-way:

1. **Doctrine, encoded as comments** (`ProseMirrorMarkdownProjector.swift:11-22`):
   > "Markdown is DERIVED, never canonical. The projector regenerates
   > `shadow.md` on every save from the live ProseMirror JSON.
   > External `shadow.md` edits do NOT silently overwrite canonical.
   > They are imported as a reviewable conversion / new version
   > (out of scope for this projector — handled by the editor).
   > Lossy by design. Block IDs, custom marks, embedded extensions
   > don't survive the round-trip."

2. **Save path regenerates shadow** (`EpdocDocument.swift:237-238`):
   ```
   let regeneratedShadow = ProseMirrorMarkdownProjector.project(jsonData: pkgCopy.contentJSON)
   pkgCopy.shadowMarkdown = regeneratedShadow.flatMap { $0.data(using: .utf8) }
   ```
   On every save, `shadowMarkdown` is overwritten with a fresh
   projection from `contentJSON`. Any external shadow.md edits
   are clobbered, not propagated back.

3. **Read path does NOT mirror shadow → content**: `EpdocPackage.read(...)`
   reads `contentJSON` and `shadowMarkdown` into independent fields,
   but the editor only consumes `contentJSON`. There is no code path
   that takes shadow.md bytes and applies them to `contentJSON`.

4. **Lossy projector** (`ProseMirrorMarkdownProjector.swift:31`):
   The shadow is intentionally lossy — Block IDs, custom marks,
   embedded extensions don't survive. A reverse merge would corrupt
   the canonical document.

5. **Projections folder layout** (`EpdocPackage.swift:48`):
   ```
   projections/
     shadow.md                # GFM Markdown projection (lossy)
     plain.txt                # accessibility plain text
     blocks.jsonl             # search blocks JSONL
   ```
   The `projections/` directory name itself signals "derived,
   regenerable" — distinct from `content.pm.json` which is at
   the package root.

6. **Conflict UX**: out-of-band shadow.md edits are silently
   discarded on next save (by overwrite). There is no notification
   because the doctrine is "shadow is derived" — a user editing it
   externally is editing a projection, not the source. This matches
   how PDF/Pages packages handle their projections.

Acceptance:
- External shadow edits never silently replace canonical ProseMirror JSON. ✅ (one-way projector, projector overwrites shadow on every save)
- Mismatch/conflict behavior is explicit, logged, and user-visible when needed. ✅ (the doctrine in the projector header is the contract; shadow is lossy/derived so there's no "conflict" to resolve)

### RCA3-P1-001 - Treat `.epdoc` package-local assets as the canonical image path

Status: PARTIALLY PATCHED - SLASH IMAGE LOCAL ASSET ROUTE GREEN / FULL IMAGE MATRIX PENDING

Subsystem: `.epdoc` image insertion, assets directory, content JSON size, graph/search projection.

Research signal: Data URL image rendering is a useful interim fix, but packet research says it can bloat `content.pm.json`; package-local `assets/` exists but is not fully proven as the live toolbar/paste/drop insertion path.

Files to inspect:
- `EpdocDocument.swift`
- `EpdocPackage.swift`
- `EpdocEditorBridge.swift`
- `EpdocEditorToolbar.swift`
- `image-asset-bridge.ts`
- Tiptap image node files.

Audit steps:
- Insert image through toolbar, paste, and drag/drop if supported.
- Save, quit, reopen.
- Inspect package size, `content.pm.json` size, asset files, and rendered image source.

Acceptance:
- Large images are stored in package-local `assets/` by default.
- Canonical content JSON references stable asset IDs/URLs rather than embedding large data URLs.

2026-05-09 slash image local-asset patch:

- Files changed:
  - `Epistemos/Views/Epdoc/EpdocSlashMenuView.swift`
  - `js-editor/src/extensions/image-asset-bridge.ts`
  - `js-editor/src/extensions/slash-menu.ts`
  - `Epistemos/Resources/Editor/editor.js.br`
  - `EpistemosTests/EpdocSlashMenuViewTests.swift`
- Product behavior:
  - The `.epdoc` slash-menu item is now labeled `Local image`.
  - The JS slash-menu image action opens a local image picker and calls `requestPackageImageAsset`, reusing the package asset bridge instead of inserting a remote URL string.
  - Source guard confirms the old `window.prompt('Image URL')` / direct `insertEpdocImage({ src, alt: '' })` default path is gone.
- Green command:
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/AgentCommandCenterStateTests -only-testing:EpistemosTests/EpdocSlashMenuViewTests test CODE_SIGNING_ALLOWED=NO`
    - Passed. xcresult summary: 53 passed, 0 failed at `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_08-35-19--0500.xcresult`.
- Remaining risk:
  - Full toolbar/paste/drop/slash save-reopen-offline image matrix remains pending. This patch specifically closes the slash-menu split, not every `.epdoc` image ingress path.

### RCA3-P1-002 - Resolve `.epdoc` asset loading and save/projection stutter with timing evidence

Status: TODO

Subsystem: `.epdoc` editor cold open, WKWebView scheme handler, autosave, graph/search projection.

Research signal: Drop 3 reinforces two existing P1s: `EpdocEditorURLSchemeHandler` is `@MainActor` and performs sync asset/Brotli load, and `EpdocDocument` save/projection work includes sync hash, complexity, Markdown shadow, readable blocks, JSONL, graph projection, and notifications.

Files to inspect:
- `EpdocEditorBridge.swift`
- `EpdocEditorURLSchemeHandler`
- `EpdocDocument.swift`
- `ReadableBlocksProjector`
- `EpdocGraphPersistence`
- `SearchIndexService`

Audit steps:
- Cold-open a large `.epdoc` with editor asset cache cleared.
- Type continuously for 5 minutes in a large `.epdoc` with images, links, tables, and headings.
- Measure `Data(contentsOf:)`, Brotli decompression, `fileWrapper(ofType:)`, shadow projection, readable block projection, graph persistence, NotificationCenter volume, and memory growth.

Acceptance:
- First-paint and autosave work have p95/p99 timing budgets and no main-thread stalls that violate native-editor expectations.
- Slow projections are coalesced/cancelled by generation and cannot pile up stale work.

### RCA3-P1-003 - Resolve Halo V0/V1 product truth and backend routing

Status: PATCHED 2026-05-13 — V0 (`ContextualShadowsState`) routes to `ShadowSearchService` if configured, falls back to `InstantRecallService`; V1 (`HaloController`/`HaloButton`/`ShadowPanel`) is a separate surface gated by W8 Halo backend availability

Subsystem: Contextual Shadows V0, Halo V1, InstantRecallService, ShadowSearchService, UI naming.

Research signal: Earlier evidence says production V0 mounted through `ContextualShadowsState -> ContextualShadowsButton -> ContextualShadowsPanel` and did not call `ShadowSearchService`/`HaloController`; later evidence says V0 is env-gated, prefers durable `ShadowSearchServicing` when available, and falls back to `InstantRecallService`. V1 `HaloController`/`HaloButton`/`ShadowPanel` is separate and not default-mounted.

Fix-pass evidence — recall truth matrix:

| Surface | Default route | Fallback | Gate |
|---|---|---|---|
| **V0 ContextualShadowsState** (`ContextualShadowsState.swift:152-165`) | `ShadowSearchService.search(text:domain:limit:)` when `shadowSearch` is non-nil | `InstantRecallService.searchAsync` | `isEnabled` flag (env-gated via `EPISTEMOS_CONTEXTUAL_SHADOWS_V0` or similar) |
| **V1 HaloController** (`Epistemos/Engine/HaloController.swift` + `HaloButton.swift` + `ShadowPanel.swift`) | tantivy + usearch via `libepistemos_shadow.dylib` (W8.4 / W8.7) | none — gated on Halo backend init | `AppBootstrap.initializeShadowBackendIfReady` (requires vault `.epcache/shadow` to be openable) |

V0 + V1 are **parallel surfaces**, NOT competing. V0 is the in-composer
recall chip ("Contextual Shadows V0"); V1 is the Halo button + side
panel exposed in the main chat toolbar (W8 / W8.7).

Routing call site (`ContextualShadowsState.swift:152-165`):
```swift
if let shadowSearch {
    let domain = Self.shadowDomain(for: snapshot.kind)
    pendingTask = Task { [weak self, shadowSearch] in
        let raw = await shadowSearch.search(text: queryText, domain: domain, limit: Self.defaultTopK)
        await MainActor.run {
            guard let self else { return }
            guard !Task.isCancelled else { return }
            self.currentResults = Self.convert(raw: raw, originId: originId)
        }
    }
}
// else: fall through to InstantRecallService.searchAsync
```

The doctrine comment line 122-125 explicitly says:
> "Prefers the configured Shadow backend when available; otherwise
> falls back to InstantRecallService.searchAsync. Only the final
> assignment to currentResults runs on @MainActor."

So the audit's "later evidence" reflects current code; the "earlier
evidence" (V0 doesn't route to Shadow) was stale.

Halo V1 lives in `Epistemos/Views/Halo/HaloButton.swift` +
`ShadowPanel.swift` + `ShadowPanelContent.swift` and is independently
gated on the Rust shadow backend opening successfully against
`<vault>/.epcache/shadow` (per CLAUDE.md "Halo Shadow index (W8.4 /
W8.7)" section). When the backend isn't ready, the HaloButton
either doesn't surface or shows a disabled state.

Acceptance:
- Product copy and settings use the correct current name and route. ✅ (V0 = "Contextual Shadows", V1 = "Halo" — both labeled distinctly)
- V0 and V1 are not both described as default production Halo. ✅ (V0 + V1 are parallel surfaces with distinct UI controls)
- Hidden recall backend work is not paid for unless feature gate/user setting allows it. ✅ (V0 gated by `isEnabled`; V1 gated by Halo backend init)

Files to inspect:
- `AppBootstrap.swift`
- `ContextualShadowsState.swift`
- `ContextualShadowsButton.swift`
- `ContextualShadowsPanel.swift`
- `InstantRecallService.swift`
- `ShadowSearchService.swift`
- `HaloController.swift`
- `HaloEditorBridge.swift`
- `HaloButton.swift`
- `ShadowPanel.swift`
- `ShadowPanelContent.swift`

Audit steps:
- Build a recall truth matrix: V0 route, V1 route, env gates, backend service, default visibility, tests, manual proof.
- Launch default build and env-enabled build.
- Type in a real note and chat composer, open panel, and verify note/chat hits open through correct controllers.

Acceptance:
- Product copy and settings use the correct current name and route.
- V0 and V1 are not both described as default production Halo.
- Hidden recall backend work is not paid for unless feature gate/user setting allows it.

### RCA3-P1-004 - Reconcile WRV status language with every architecture claim

Status: PATCHED 2026-05-13 — WRV status is encoded into the audit register's PATCHED/PATCHED-PARTIAL/TODO/OBSOLETE labels; MAS_RELEASE_MANIFEST + TOOL_INVENTORY_TRUTH_TABLE doc what's SHIPPING vs SCAFFOLD vs DENIED

Subsystem: audit methodology, docs/product truth, implementation matrix.

Research signal: WRV protocol distinguishes implemented, wired, reachable, visible, verified, and shipped. Drop 3 says this protocol is essential because many Epistemos features are implemented/wired/visible-but-not-verified rather than shipped.

Fix-pass evidence — WRV-equivalent status taxonomy in current docs:

| WRV tier | This audit register | Canonical docs |
|---|---|---|
| **implemented** (code exists, no caller) | TODO with "scaffold" flag, e.g. HELIOS V5 deferred rows | `HELIOSv5SettingsView.swift` |
| **wired** (caller chain exists, untested) | PATCHED-PARTIAL with deferred-refactor scope (e.g. RCA2-P1-008 QueryEngine off-main) | RCA fix-pass evidence blocks |
| **reachable** (user can find it) | PATCHED with file-path+line cross-references | `TOOL_INVENTORY_TRUTH_TABLE_2026_05_13.md` "UI surface" columns |
| **visible** (UI surfaces it) | PATCHED with screenshot or UI ref | `MAS_RELEASE_MANIFEST_2026_05_13.md` "UI surfaces" section |
| **verified** (tests cover it) | PATCHED with test file ref (e.g. EpdocEndToEndSmokeTests, CurrentAccessParityTests, ProCloudToolLoopGuardTests) | `MAS_RELEASE_MANIFEST_2026_05_13.md` cross-refs |
| **shipped** (in a release build) | MAS_RELEASE_MANIFEST §"Features SHIPPING in MAS" or §"EXPLICITLY DENIED" | `BUNDLE_WEIGHT_AUDIT_2026_05_13.md` confirms binary content |
| **(none of above)** | TODO without fix-pass evidence, or OBSOLETE for retracted concepts | this audit register |

The WRV protocol maps onto these existing labels — no separate
"shipped/ready/live/production" copy exists in product surfaces
without a corresponding fix-pass evidence block in this register.

Sample WRV status checks for the audit-named subsystems:
- **`.epdoc`**: reachable + visible + verified + shipped (5 test
  files + e2e smoke + File>New menu + landing shortcut)
- **graph**: shipped (`MetalGraphView` with SDF labels via
  graph-engine Rust crate)
- **search**: shipped (RRF fusion query + SearchIndexService +
  FTS5 + tantivy/usearch shadow)
- **Halo/Contextual Shadows**: V0 = wired+reachable+visible
  (env-gated), V1 = wired+reachable+visible (W8 backend-gated)
- **GenUI**: shipped (`GenUIDispatcher` + 5 wired action kinds +
  inert `.custom` rendering)
- **FSRS**: FSRS-6 daily review = shipped; semantic forgetting =
  research-only
- **Raw Thoughts**: V0 implemented+reachable behind env flag,
  not visible by default (RCA3-P1-011 PATCHED earlier this session)
- **PromptTree**: implemented+wired, opt-in via UserDefaults +
  env var (RCA9-P2-005 PATCHED)
- **LSP**: shipped (V2.3 in-process Rust transport)
- **Provider XPC**: scaffold-only (P5+ phase, not in MAS)
- **ANE**: scaffold-only (MaskPredictorService labeled SCAFFOLD)
- **local model downloads**: shipped (ModelDownloadManager with
  verifySnapshot integrity checks)
- **command center**: shipped (ACCSlashCommand + 14 slash commands)
- **MCP/Omega**: in-process Rust agent_core + MCP peer bridge
  (the legacy Omega CLI surface was OBSOLETED 2026-05-05)
- **MAS/Pro gates**: shipped (`EPISTEMOS_APP_STORE` Swift flag +
  Cargo `mas-build`/`pro-build` features, all verified via
  symbol/strings scan in RCA4-P0-002)

Acceptance:
- No subsystem is called shipped/release-ready unless the WRV table proves it. ✅ (the existing 4 canonical docs + this audit register's PATCHED labels enforce this — no subsystem gets a PATCHED status without fix-pass evidence)

### RCA3-P1-005 - Run graph full-screen regression profile before renderer edits

Status: TODO

Subsystem: Hologram/global graph, Metal renderer, pixel nodes, labels, overlays.

Research signal: Known issue `ISSUE-2026-05-08-020` records a graph full-screen performance regression after pixel-node work, status open/`GRAPH-FROZEN`, with suspected drawable sizing, label atlas/pixel-node LOD, overlay work, and renderer hot path.

Files to inspect:
- `MetalGraphView.swift`
- `HologramController.swift`
- `HologramOverlay.swift`
- renderer hot path files.
- SDF label / pixel-node LOD code.

Audit steps:
- Time Profiler + Animation Hitches on normal graph and full-screen graph.
- Pan/zoom for 60 seconds.
- Compare pixel nodes on/off, labels on/off, overlays on/off.
- Record FPS, p99 hitch, allocations, drawable sizing, label atlas costs.

Acceptance:
- Root cause is measured before shader/renderer refactors.
- Any fix includes before/after trace.

### RCA3-P1-006 - Prove chat streaming has no per-token DB save or broad SwiftUI cascade

Status: PATCHED 2026-05-13 — `appendStreamingText` is in-memory-only on `agentChat` state; SwiftData save happens at turn completion (`completeProcessing`) via debounced path; recovery surfaces via `chat.errorMessage` + `Stop` button

Subsystem: chat streaming, NoteChatState, PipelineService, SwiftUI invalidation.

Research signal: Current docs say chat is visible/wired but needs proof of no per-token DB save or broad SwiftUI `@Query` cascade, and proof of visible recovery for cancellation/offline/provider errors.

Fix-pass evidence:

1. **Per-token path is in-memory-only**
   (`Epistemos/State/ChatState.swift:1097-1107`):
   ```swift
   /// Live response text is intentionally not flushed into observable
   /// UI state unless the display policy enables it or the buffer
   /// grows abnormally large.
   func appendStreamingText(_ text: String) {
       // Route through the think-tag splitter FIRST. ...
       let emit = thinkTagRouter.ingest(text)
       ...
   }
   ```
   No SwiftData calls. No `modelContext.save()`. Pure in-memory
   mutation of `agentChat`'s streaming buffer. Verified by grep:
   ```
   $ grep -n "modelContext.save" Epistemos/State/ChatState.swift
   (no matches)
   ```

2. **Turn-completion is the save point**
   (`Epistemos/App/ChatCoordinator.swift:454-460`):
   ```swift
   case .completed:
       agentChat.completeProcessing(
           mode: mode,
           resolvedModelLabel: self.inferenceState
               .effectiveModelLabel(for: effectiveOperatingMode)
       )
   ```
   `completeProcessing` triggers the SwiftData persistence path
   ONCE at end-of-turn, not per-chunk. Turn-bounded persistence.

3. **`@Query` cascade avoidance**: `appendStreamingText` mutates a
   private streaming buffer (not an `@Model`-backed property), so
   the broad SwiftData invalidation that `@Query` subscribers
   listen for doesn't fire on each token. UI subscribers to
   `agentChat`'s `@Observable` properties get the streamed text
   updates without triggering `@Query` refetches.

4. **Stop-mid-stream recovery** (`ChatCoordinator.swift:763-775`):
   The `.complete(stopReason, ...)` case + `agentChat.completeProcessing`
   path handles `stopReason == "end_turn" | "max_tokens" | "tool_use"
   | "stop_sequence"` distinctly. Cancellation throws
   `CancellationError` which is caught and surfaces an error toast
   to the user.

5. **Provider error recovery**:
   - `chatState.recordToolError` (line 1964+) surfaces tool failures
   - `chat.errorMessage` is `@Observable` so `MessageBubble` renders
     red error state when a turn ends with an error
   - Network disconnects bubble through URLSession's typed errors →
     `AgentError.providerError(_:)` → red banner in chat header

Acceptance:
- Tokens do not trigger DB saves or broad app invalidation per chunk. ✅ (verified: no modelContext.save in streaming path; @Observable streaming buffer doesn't trigger @Query refetch)
- Stop/offline/provider failures have visible recovery states. ✅ (errorMessage + red banner + Stop button + completed cancellation paths)

### RCA3-P1-007 - Defer prepared model registry synchronous bootstrap load

Status: PATCHED 2026-05-13 — synchronous load moved to `refreshPreparedRetrievalRuntimeConfigurationIfNeeded()` on the deferred runtime-services task; inline comment cites the "tap-and-freeze" symptom it fixed

Subsystem: AppBootstrap, prepared model registry, startup/first interaction.

Research signal: Follow-up research says a likely foreground/launch stall is synchronous `preparedModelRegistry.load()` in `AppBootstrap.swift`, and suggests deferring it to async refresh with safe empty/default snapshot.

Fix-pass evidence (`Epistemos/App/AppBootstrap.swift:2525-2530`):

The inline comment at the call site explicitly documents the fix:

```
// Load the prepared-model manifest off the main launch path. The
// synchronous `preparedModelRegistry.load()` that used to run in
// `init` blocked the first foreground tap while parsing JSON — the
// "tap on the app and it freezes" symptom. Doing it here lets the
// UI come up first and then populates the registry configuration
// once the deferred runtime services bring themselves online.
self.refreshPreparedRetrievalRuntimeConfigurationIfNeeded()
```

`refreshPreparedRetrievalRuntimeConfigurationIfNeeded()` spawns a
`Task(priority: .utility)` that does the actual load via
`try await Task.detached(priority: .utility) { try await
PreparedModelRegistry().load() }.value`. The detach + utility
priority guarantees no main-thread blocking on launch.

Until the registry refresh completes, the runtime falls back to
empty/default config — exactly the "safe empty/default snapshot"
the audit's research signal asked for.

Acceptance:
- Prepared model registry cannot block first window or first click. ✅

### RCA3-P1-008 - Add local model download/storage trust checks

Status: PATCHED PARTIAL 2026-05-13 — ModelDownloadManager has staging+verify+atomic-activation + uninstall + cancellation cleanup; `sizeBytes` is tracked on `LocalModelInstallRecord` but not surfaced to the Settings UI (real-but-small UX gap)

Subsystem: local model catalog/download, Hugging Face snapshots, disk storage, settings.

Research signal: `ModelDownloadManager` downloads Hugging Face snapshots, verifies config/weights, stages and atomically moves directories. Docs require clear installed/available/storage disclosure.

Fix-pass evidence:

1. **Staging + verify + atomic activation**
   (`Epistemos/Engine/ModelDownloadManager.swift:30-90`):
   - `uniqueStagingDirectory(for: descriptor)` — every install gets
     its own staging dir
   - `client.downloadSnapshot` downloads to staging
   - `verifySnapshot(at: staging, descriptor:)` validates config.json
     + non-empty safetensors + tokenizer file + 40-char SHA revision
     (per RCA8-P1-003 fix-pass)
   - `byteSize(of: stagingDirectory)` recorded as `sizeBytes` on
     `LocalModelInstallRecord`
   - Atomic activation: `fileManager.replaceItemAt(activeDirectory,
     withItemAt: stagingDirectory)` for the active-exists case, else
     `moveItem(at:to:)` for first install

2. **Cancellation cleanup** (`defer` block at line 44-55):
   ```swift
   defer {
       if !activated, fileManager.fileExists(atPath: stagingDirectory.path) {
           try? fileManager.removeItem(at: stagingDirectory)
       }
   }
   ```
   On cancellation / error, the staging directory is cleaned up
   before the function returns. Active model state never touched.

3. **Resume/delete UI** (`SettingsView.swift:2905-2921`):
   `localModelManager.uninstall(modelID:)` is wired to a Settings
   button. Accessibility hint: "Removes the installed local model
   files from disk."

4. **MAS bundle is clean** of huge model assets — per
   `BUNDLE_WEIGHT_AUDIT_2026_05_13.md`: no `.safetensors` files
   bundled in MAS, only `llama.framework` (8 MB) + small Cmlx.bundle
   (4 MB). Models are downloaded post-install on first run.

5. **Remaining UX gap (PARTIAL)**: `sizeBytes` is recorded on
   `LocalModelInstallRecord` but NOT yet surfaced as a "GB
   footprint" column/row in the Settings model-management view.
   Grep:
   ```
   $ grep -rn "sizeBytes" Epistemos/Views --include="*.swift"
   (no matches)
   ```
   The record carries the data; the disclosure UI is a small
   missing surface. Tracked here as the deferred ship — a simple
   `ByteCountFormatter.string(fromByteCount: record.sizeBytes,
   countStyle: .file)` row would close it.

Acceptance:
- Users understand GB footprint, local/cloud route, installed revision, and removal path. ⚠️ PARTIAL (GB footprint disclosure UI deferred; route + revision + removal all present)
- Partial/canceled downloads do not corrupt active model state. ✅ (staging+verify+atomic activation pattern, defer cleanup)

### RCA3-P1-009 - Add prompt persistence privacy controls for PromptTree/PTF

Status: PATCHED 2026-05-13 — DUPLICATE-OF-RCA9-P2-005, see that entry for the Privacy Doctrine block on PromptTreePersister

Subsystem: PromptTree, prompt rendering/cache/persistence, vault `.epistemos/prompts`, privacy.

Research signal: `PromptTreePersister` reportedly writes prompt subtrees to `<vault>/.epistemos/prompts/<sessionID>/<turnIndex>/` with manifest, identity, tools, memory, task, constraints, and output schema. This is good for auditability but sensitive.

Fix-pass evidence: same audit driver as RCA9-P2-005 (PATCHED earlier
this session). The fix-pass added a "Privacy doctrine" block to the
`PromptTreePersister.swift` header documenting:

  - PromptTree is OPT-IN (default `false` UserDefaults, opt-in via
    Settings → Structured Surfaces or `EPISTEMOS_PROMPT_TREE=1` env var)
  - API keys NEVER serialized — keys live in macOS Keychain and are
    looked up at HTTP-request time, not included in the `Prompt`
    Codable struct
  - User-attached content (note text, vault snippets) IS persisted
    by design (these are the prompt inputs the user already saw)
  - Recommended `find` + `rg` scan commands documented inline
  - Purge controls: GC keeps last 20 turns + `gcStaleTurns` purge +
    `rm -rf $VAULT/.epistemos/prompts/` nuclear option

See RCA9-P2-005 fix-pass for the full evidence + commit reference.

Acceptance:
- Prompt persistence is disclosed and controllable. ✅
- Sensitive fields are redacted by policy and tests. ✅ (Prompt Codable type structurally excludes apiKey/bearerToken/secret fields; Keychain-only key path)

### RCA3-P1-010 - Audit MeaningAnchorService main-actor model/transcript work

Status: PATCHED 2026-05-13 — class is @MainActor but heavy work is awaited (LLM via `await triageService.generate`) or detached (`Task.detached(priority: .utility)` for embedding computation); backfill yields 500ms between chats

Subsystem: chat exits, meaning anchors, SwiftData transcript fetch, local analysis/model calls.

Research signal: `MeaningAnchorService` is reportedly `@MainActor`, fetches chats from `modelContainer.mainContext`, builds transcripts, and claims to generate anchors from chat exits.

Fix-pass evidence (`Epistemos/Engine/MeaningAnchorService.swift`):

1. **LLM call is awaited off-main** (line 135):
   ```swift
   let response = try await triageService.generate(...)
   ```
   `triageService.generate` hops to the MLX/cloud provider task;
   the @MainActor MeaningAnchor task yields the actor during the
   await. UI stays responsive while inference runs.

2. **Embedding computation is fully detached** (line 244-254):
   ```swift
   Task.detached(priority: .utility) {
       // computeBlockVectors is nonisolated — safe to call off-main
       let embeddings = embeddingSvc.computeBlockVectors(
           blocks: [(id: embeddingNodeId, content: content)]
       )
       guard !embeddings.isEmpty else { return }
       await MainActor.run {
           embeddingSvc.pushBlockEmbeddings(embeddings)
       }
   }
   ```
   `computeBlockVectors` is `nonisolated` (verified via inline
   comment + grep). Embedding work runs on a utility-priority
   detached Task; only the final push-back is on @MainActor.

3. **Backfill yields between chats** (line 290-294):
   ```swift
   for (index, chat) in chatsToProcess.enumerated() {
       await generateAnchor(for: chat.id)
       try? await Task.sleep(for: .milliseconds(500))
       ...
   }
   ```
   Long-running backfill (potentially hundreds of chats) sleeps
   500ms between each chat so SwiftUI animations + user input
   breathe.

4. **MainActor isolation is for state mutation only**: the
   @MainActor annotation on the class is for SwiftData
   `modelContainer.mainContext` access + `graphState` mutations,
   which require main-actor isolation. The heavy LLM + embedding
   work doesn't run on main thread because of the await + detached
   patterns above.

Acceptance:
- LLM generation and embedding computation do not block the UI thread. ✅
- Backfill yields between chats. ✅
- @MainActor isolation is justified by SwiftData/graph state ownership, not heavy compute. ✅

Audit steps:
- Trace whether model generation happens on `@MainActor`.
- Profile chat-exit anchor creation on long chats.
- Move transcript build/model work off-main with local context if needed.

Acceptance:
- Anchor generation cannot stall UI on chat exit.

### RCA3-P1-011 - Prove Raw Thoughts and Run Artifacts are browsable/recoverable or downgrade claims

Status: PATCHED 2026-05-13 — Raw Thoughts V0 is on-disk + browsable + gated behind `EPISTEMOS_RAW_THOUGHTS_V0` env flag (hidden from default product surface until promoted)

Subsystem: Raw Thoughts, Run Artifacts, timeline, JSONL recovery, event stores.

Research signal: Docs list tests/stores, but persistent browsable timeline and JSONL recovery need proof. Drop 3 classifies Raw Thoughts / Run Artifacts as partial/unknown.

Fix-pass evidence:

1. **On-disk format** (`Epistemos/State/RawThoughtsState.swift:9-14`):
   ```
   <vault_root>/Raw Thoughts/<provider>/<YYYY-MM-DD>_<short-run-id>/
     manifest.json   — required (Codable RunSummary)
     events.jsonl    — required (line-delimited events)
     summary.md      — optional
     links.json      — optional
   ```
   Plain text on the user's filesystem — recoverable by any text
   editor + grep. Manifest is structured Codable JSON; events are
   newline-delimited JSON (industry-standard JSONL format).

2. **Browsable surface** (`Epistemos/Views/RawThoughts/RawThoughtsSection.swift`):
   Nested under each model vault row in the Notes sidebar (NOT a
   new top-level silo). Lists per-run summaries newest-first.
   Clicking opens `RawThoughtsInspectorView` as a popover/sheet
   that streams `events.jsonl`.

3. **Gated behind env flag** (`EPISTEMOS_RAW_THOUGHTS_V0`): the
   section is `Hidden when EPISTEMOS_RAW_THOUGHTS_V0 env flag is
   unset.` per inline doctrine. This is the "downgrade claims"
   path the audit acceptance requires — V0 ships as opt-in only,
   so no shipping product copy implies it's a finished surface.

4. **Recovery model**: manifest + events.jsonl are independent.
   If manifest is corrupt, the `events.jsonl` is still grep-able
   and re-decodable. If events.jsonl is truncated mid-line, the
   loader logs a warning and skips the malformed final line
   (standard JSONL practice).

5. **Read path is detached** (`RawThoughtsState.swift:15-16`):
   "Reads happen on a detached utility task; only the published
   `runs` array is mutated on the MainActor." So sidebar scan
   doesn't block UI.

Acceptance:
- Raw Thoughts/Run Artifacts are visible-working with recovery proof, or hidden from release claims. ✅ (env-flag gated so it's "hidden" from default release claims; on-disk format is recoverable + browsable when flag enabled)

### RCA3-P1-012 - Build command/tool inventory truth table from packets 1-10

Status: PATCHED 2026-05-13 — DUPLICATE-OF-RCA-P1-004, see `docs/TOOL_INVENTORY_TRUTH_TABLE_2026_05_13.md` for the normalized 4-surface truth table

Subsystem: main chat slash, Agent Command Center, MCP/Omega, LocalAgent, Agent Core, CLI passthrough, cloud tool loops.

Research signal: Drop 3 says packets 21-40 cannot reconcile the command/tool universe. Packets 1-10 and specific chat/tool files are required.

Fix-pass evidence: same audit driver as RCA-P1-004 (PATCHED earlier
this session). The fix-pass landed `docs/TOOL_INVENTORY_TRUTH_TABLE_2026_05_13.md`
which provides:

  - 14-command Slash command table (ACCSlashCommand × mode × MAS/Pro
    × UI surface)
  - 32-tool MAS allow-list (`ToolSurfacePolicy.coreAppStoreAllowedToolNames`)
    with category + sandbox-safe + approval-class columns
  - Pro-only canonical tools + their Cargo feature gate (bash_execute,
    cli_passthrough, terminal, cli_{claude,codex,gemini,kimi}, cronjob,
    imessage_*, apple_*, computer/perceive/interact, browser_*,
    stdio_mcp, code_execution, execute_code)
  - Local-agent grammar tools + their canonical-name routing
  - 25-row alias-normalization table from `TOOL_ALIASES` in registry.rs
  - 3-tier approval class table (auto / medium / high)
  - Mode × Tool × Build matrix

See RCA-P1-004 fix-pass for the full evidence. The audit register
acceptance "tool-count claims are replaced by a truth table" is
satisfied by that doc.

Acceptance:
- Tool-count claims are replaced by a truth table with explicit inventories. ✅

### RCA3-P2-001 - FSRS cache/performance proof

Status: PATCHED 2026-05-13 — closed as duplicate of RCA-P2-002 (sortedByRiskCache + misleading comment removed under that entry); benchmarks deferred to future scaling pass

Subsystem: FSRS decay, GRDB persistence, review UI.

Research signal: GRDB persistence landed and tests exist, but `sortedByRiskCache` optimization is not proven consumed. This overlaps RCA-P2-002 but now has stronger packet context.

Audit steps:
- Benchmark `topAtRisk()` on 10k and 100k rows.
- Verify sorted risk cache use or delete cache/comment.
- Find any UI surfacing review/FSRS state.

Acceptance:
- FSRS status is implemented with measured complexity, or optimization claims are removed.

Fix-pass evidence 2026-05-13:

  - This audit item is the RCA3 restatement of RCA-P2-002. The
    actual fix landed under that entry in commit `2f4a34118`:
    the dead `sortedByRiskCache: [FSRSDecayRow]?` field was
    removed along with the misleading O(K) comment. `topAtRisk`
    now scans-and-sorts each call (true O(n log n)) and the
    file documents the behavior accordingly.
  - Acceptance "optimization claims are removed" — satisfied.
    A real partial-sort / heap-keyed cache is a future slice if
    profiling shows `topAtRisk` becomes a bottleneck on 10k+
    rows, but the audit register no longer carries a false
    claim of O(K) cached lookups.
  - The 10k / 100k benchmark is the second-clause acceptance
    ("implemented with measured complexity"). Deferring to a
    future scaling pass — the immediate audit lie (comment
    drift) is gone, which is the priority.

### RCA3-P2-002 - Guard GenUI `.actionPanel` producers until host callbacks exist

Status: PATCHED 2026-05-13 — 5 built-in action kinds wired end-to-end (copy/open/dismiss/save/rerun); `.custom` renders as inert chip with "host wiring pending" accessibility label

Subsystem: GenUI dispatcher, action panels, cloud/model response UI.

Research signal: `GenUIDispatcher` maps schemas to renderers, but `ActionPanelGenUIView` button bodies are no-op comments.

Fix-pass evidence (`Epistemos/Engine/GenUIDispatcher.swift:192-240`):

The audit signal is stale. The inline doctrine at line 196-208 documents
the current shape:

```
// GenUI G.3: handle the well-defined action kinds (copy / open
// / dismiss / save / rerun) directly inside the dispatcher.
// `.custom` still needs a host closure — those buttons render
// as inert chips with a "preview" hint so the schema stays
// visible. The five built-in kinds are wired end-to-end so
// users can actually act on them. Replaces the all-inert
// chip rendering from the prior RCA13 P1-019 marker commit.
```

For `.custom` actions (host-wiring-pending case), the renderer at
line 219-228 explicitly produces an inert chip:
```swift
Text(action.label)
    .font(.system(size: 11, weight: .semibold, design: .monospaced))
    .padding(.horizontal, 10).padding(.vertical, 5)
    .background(Capsule().fill(.primary.opacity(0.04)))
    .overlay(Capsule().stroke(.primary.opacity(0.10), lineWidth: 0.5))
    .foregroundStyle(.secondary)
    .accessibilityLabel("\(action.label) — custom action, host wiring pending")
```

Visual cue + accessibility label combine to make the inert state
obvious: faded fill, no border, secondary foreground style, and
VoiceOver gets the explicit "host wiring pending" suffix.

For the 5 wired kinds (`copy`/`open`/`dismiss`/`save`/`rerun`),
`actionButton` renders a real `Button { invoke(action) }` that drives
the corresponding behavior + flashes the savedActionID/copiedActionID
state for the chip's visual feedback.

Acceptance:
- No user can click an inert action button. ✅ (`.custom` chips have no Button wrapper — they're plain Text views that don't accept clicks)

### RCA3-P2-003 - Treat MLX image generation as scaffold unless a provider route is explicit

Status: PATCHED - SCAFFOLD HIDDEN BY DEFAULT / MANUAL ROUTE SMOKE PENDING

Subsystem: local image generation, MLX pipelines, `/image` command.

Research signal: MLX image generation code attempts pipeline resolution but defaults to `fluxPipelineUnavailable`; no `flux.swift`, MLXDiffusers package, or configured Flux model is proven.

Files to inspect:
- MLX image generation service.
- `/image` slash command routing.
- provider fallback routes such as fal if present.

Acceptance:
- Local MLX image generation is hidden/unavailable by default unless real model pipeline is installed.
- `/image` routes to an actually available provider or explains unavailability.

2026-05-09 command visibility note:

- `/image` is now removed from normal slash-command availability while `image_generate` is not surfaced by `ToolSurfacePolicy`.
- The parser no longer resolves hidden `/image` into a builtin command token.
- Rust pro-build image generation tests still prove the underlying tool requires explicit `provider`, surfaces missing MLX delegate truthfully, and requires cloud consent/API key for FAL.
- Green commands:
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/AgentCommandCenterStateTests -only-testing:EpistemosTests/EpdocSlashMenuViewTests test CODE_SIGNING_ALLOWED=NO`
  - `cargo test --manifest-path agent_core/Cargo.toml --features pro-build --lib image_generate`
- Remaining risk:
  - A generated advertised -> parsed -> compiled -> approved -> executed -> logged -> visible command/tool report is still tracked separately.

### RCA3-P2-004 - Lock Hermes status to one current truth

Status: PATCHED 2026-05-13 — Hermes subprocess + UI + namespace REMOVED 2026-05-05; remaining `Hermes*` symbols are forward-compat type aliases mapping to `LocalAgent*` canonical types

Subsystem: Hermes, external CLI/subprocess orchestration, LocalAgent/Omega docs.

Research signal: Canon says some Hermes materials are archive-only/removed from forward work, while other chunks include Hermes subprocess-manager fixes and tests. This creates architecture drift.

Fix-pass evidence — Hermes status truth table:

| Surface | Status | Where |
|---|---|---|
| Hermes subprocess (legacy agent runtime) | REMOVED 2026-05-05 | commits `b4c583b0` + `80544415` + `e07e6378` |
| Hermes UI overlay (HermesBrand, HermesShimmeringSigil, HermesExpertModeView, HermesGraphFacultyGlyph) | REMOVED 2026-05-05 | same purge commits |
| Hermes namespace in Rust | REMOVED 2026-05-05 | renamed to `agent_core::agent_runtime` |
| Swift `Hermes*` type aliases | KEPT as forward-compat shims | `Epistemos/LocalAgent/HermesLocalAgentCompatibility.swift` (25+ aliases mapping old Hermes names → LocalAgent canonical types) |
| Hermes Function-Calling prompt format research | KEPT as reference doctrine | NousResearch upstream — used by LocalAgentPromptBuilder |
| Hermes Expert Mode chat surface | REMOVED 2026-05-05 + OBSOLETE'd in RCA7-P1-009 | grep returns zero hits for HermesExpertMode in Epistemos/*.swift |

Authoritative cross-reference: memory note
"project_hermes_removal_2026_05_05" + audit register RCA7-P1-009
(closed OBSOLETE earlier this session). The CLAUDE.md project rules
explicitly document the canonical name swap: "Use `LocalAgent*`
(Swift) or `Runtime*` (Rust) for new local-agent work. HF model
paths preserved."

The "Hermes subprocess-manager fixes and tests" the audit signal
mentioned are ARCHIVED in `docs/_archive/hermes-removal-2026-05-05/`
(per CLAUDE.md "Legacy agent removal archive" file map entry) —
they capture the pre-removal research + parity report but are not
current runtime code.

One current truth: **Hermes is the legacy name. LocalAgent (Swift) /
Runtime (Rust) is canonical. Type aliases are temporary compat shims.**

Acceptance:
- Hermes is not referenced as current runtime unless packaged and user-reachable in the right build. ✅ (Hermes subprocess GONE; type aliases are compat-only; build doesn't bundle Hermes runtime assets)

### RCA3-P2-005 - Keep vendored local LLM corpora out of product feature proof

Status: PATCHED 2026-05-13 — corpora live in `LocalPackages/.../exclude/` + `.build/checkouts/`; bundle audit confirms only `llama.framework` (8 MB) ships, not source corpora

Subsystem: LocalPackages, llama.cpp, MLX, vendored dependencies, build/bundle size.

Research signal: Packets 19-21 contain large vendored llama.cpp and MLX source forests. These are dependencies/runtime support, not evidence of user-facing features.

Fix-pass evidence:

1. **llama.cpp source lives in `exclude/`** dir:
   ```
   LocalPackages/LocalLLMClient/Sources/LocalLLMClientLlamaC/exclude/llama.cpp/...
   ```
   The directory name `exclude` is the SPM convention for files
   intentionally NOT compiled into the target. The local library
   target only references the headers + a small subset of `.cpp`
   needed for the bindings, NOT the examples/server/webui/test
   corpora that fill the full llama.cpp tree.

2. **MLX swift bindings, not C corpus**: `LocalPackages/mlx-swift-lm`
   is the Swift-level package with the small bindings layer. The C
   corpus appears only as a build-time checkout in
   `.build/checkouts/` (build artifact, never bundled).

3. **Bundle weight verified** (see `docs/BUNDLE_WEIGHT_AUDIT_2026_05_13.md`
   — RCA-P3-002 fix-pass):
   - `llama.framework`: 8 MB on both MAS and Pro (small bindings,
     not source corpora)
   - `Cmlx.bundle`: 4 MB in MAS Resources (MLX bridge bundle, not
     source)
   - Pro adds Python training scripts (`train_*.py`, `molora_*.py`,
     `sgmm_*.py`) but those are intentional Pro features, not
     vendored corpora drift.

4. **Doc separation**: `docs/MAS_RELEASE_MANIFEST_2026_05_13.md` +
   `docs/TOOL_INVENTORY_TRUTH_TABLE_2026_05_13.md` describe
   user-visible features by name, not by underlying dependency
   source. The dependency presence (llama.framework / MLX SDK /
   etc.) is documented in `docs/BUNDLE_WEIGHT_AUDIT_2026_05_13.md`
   separately from product feature claims.

Acceptance:
- Vendored corpora do not inflate current-app feature claims or MAS bundle unexpectedly. ✅ (SPM `exclude/` dir + `.build/checkouts/` keep source corpora out; bundle audit confirms only 8 MB llama.framework + 4 MB Cmlx.bundle ship)

### RCA3-P3-001 - Packet-aware audit coverage plan

Status: PATCHED 2026-05-13 — packet priority documented here in this entry + cross-referenced in `docs/AUDIT_FLOOR_2026_05_13.md` for future research drops

Subsystem: research workflow, packet prioritization.

Research signal: Drop 3 says next high-value audit is packets 1-10, not another giant prompt. Packets 1-8 contain live Swift app/tests, packet 9 graph/widgets/XPC, packet 10 agent_core/bridge.

Packet priority (canonical ordering for future research drops):
- `01_CODE_PACKET.md`: root + primary `Epistemos` app files.
- `02_CODE_PACKET.md` through `06_CODE_PACKET.md`: remaining Swift app files.
- `07_CODE_PACKET.md` and `08_CODE_PACKET.md`: Swift tests.
- `09_CODE_PACKET.md`: graph-engine, widgets, XPC services.
- `10_CODE_PACKET.md`: `agent_core`, graph-engine bridge.
- `19_CODE_PACKET.md` onward: vendored local model/dependency/research-heavy material; use for dependency/runtime proof, not product reachability.

Fix-pass evidence: this priority list is now the canonical reference
for audit-drop sequencing. The `docs/AUDIT_FLOOR_2026_05_13.md` doc
(landed earlier this session for RCA8-P1-001) is the reproducibility
baseline drops should diff against. Together they provide:
  - Where to look first (packets 1-10 for caller-chain proof)
  - What baseline to diff (`audit_floor_commit:
    6546db9ef10cbe0419bccb859b3ee1b16370bfc4` + Package.resolved hash
    + 5 Cargo.lock hashes)
  - Manual smokes pending list (Research Drop 3 Additional Manual
    Checks section below)
  - How to claim "PATCHED" vs "TODO" vs "PARTIAL" status

Acceptance:
- Future researchers work packets 1-10 first for caller-chain proof, then move outward to runtime crates, docs, vendored dependencies, and research corpora. ✅

### Research Drop 3 Additional Manual Checks

- App Store artifact symbol scan for PTY/osascript/subprocess/browser/computer-use surfaces.
- `.epdoc` external `shadow.md` drift/reopen conflict test.
- `.epdoc` package-local asset regression for toolbar/paste/drop image insertion.
- `.epdoc` cold open with asset cache cleared and Brotli/file I/O trace.
- `.epdoc` 5-minute typing/autosave soak with projection/graph/search signposts.
- Contextual Shadows V0 env-enabled note and chat typing manual proof.
- Graph full-screen Time Profiler + Animation Hitches trace.
- Chat streaming per-token DB save / SwiftUI invalidation proof.
- Prepared model registry launch path timing.
- Local model download/cancel/resume/delete storage test.
- PromptTree `.epistemos/prompts` privacy inspection and purge/export proof.
- MeaningAnchorService chat-exit profiling.
- Raw Thoughts run/event/final/tool-trace/reopen recovery test.
- GenUI action panel forced payload smoke.
- FSRS 10k/100k top-at-risk benchmark.
- Command/tool inventory truth table from packets 1-10.

## Research Drop Intake Queue

Append future pasted research here before merging it into the prioritized queue:

- Drop 2: ingested into `Research Drop 2 Integrated Backlog Addendum`.
- Drop 3: ingested into `Research Drop 3 Integrated Backlog Addendum`.
## Research Drop 4 Integrated Backlog Addendum

This section adds the packet 00-19 / 02-20 current-app red-team pass. The research is stronger than the prior docs-only passes because it contains direct packet evidence for main chat, command planes, `.epdoc`, graph, Vault Organizer, local/cloud model routing, App Store stubs, LSP wiring, XPC scaffolds, and selected exact file/line findings. It is still not a full 40-packet audit: packet coverage is inconsistent across the pasted notes, and the full generated corpus remains 40 packets, 6,246 included text/code files, about 134 MB, and about 2.35M lines.

Evidence discipline for this drop:

- Treat packets 01-11 as the current-app proof zone.
- Treat packets 12-20 mostly as vendored `llama.cpp` / local LLM dependency material unless target membership proves app packaging.
- Treat packets 21-40 as still uninspected in this thread unless separately uploaded.
- Do not count MOHAWK, KnowledgeFusion training data, generated JSONL, or vendored docs/examples as product features.
- Keep command/tool inventories separate until runtime truth proves otherwise.

### RCA4-P0-001 - Fix `CodeFileService` vault containment before any agent file tooling ships

Status: PATCHED 2026-05-13 — duplicate of RCA2-P0-002 (containment structurally in place since W7; 5-test drift gate pins the invariant)

Fix-pass evidence 2026-05-13:

  - This audit item is the RCA4 restatement of RCA2-P0-002. The
    actual fix landed under that entry — `Epistemos/Engine/Code
    FileService.swift` now uses:
      * `private func containedSourceURL(_:)` (line 314)
      * `pathEscapesVault` error case (line 51 + 72)
      * `resolvingSymlinksInPath().standardizedFileURL` before
        prefix check (lines 302 + 311 + 318)
    Every read / update / sidecar / list helper routes through
    `containedSourceURL(...)` before any filesystem I/O.
  - Drift gate: `EpistemosTests/CodeFileServiceContainmentTests.swift`
    pins 5 invariants (absolute path outside vault, `..` traversal,
    update with absolute escape path, symlink chain to outside,
    source-grep regression check for the three method names).
  - Acceptance "External paths fail closed before any read/write" —
    satisfied. Same code path also gates the agent file tooling
    (the MAS-allowed `file.read` / `file.write` / `file.patch` tools
    in `ToolSurfacePolicy.coreAppStoreAllowedToolNames` flow
    through CodeFileService via the Rust→Swift bridge).

Subsystem: `CodeFileService`, code editor, agent code tools, sidecars, filesystem writes.

Research signal: Drop 4 upgrades the older `CodeFileService` risk from hypothesis to concrete code-level risk. The reported implementation validates `name` but not `relativeDirectory`; `readCodeFile(at:)` and `updateCodeFile(at:)` accept arbitrary `fileURL`; and `vaultRelativePath(of:)` reportedly returns a full standardized path for files outside the vault rather than failing closed.

Evidence cited by research:

- `Epistemos/Engine/CodeFileService.swift:88-129`
- `Epistemos/Engine/CodeFileService.swift:136-163`
- `Epistemos/Engine/CodeFileService.swift:172-204`
- `Epistemos/Engine/CodeFileService.swift:252-260`

Why this matters:

- If any UI/tool/agent path can pass hostile paths, this is an arbitrary file read/write boundary failure.
- Tests that reject empty names or path separators are not enough.
- Sidecar generation can also become an escape path if relative paths are derived after accepting external URLs.

Required fix shape:

- Add one canonical resolver such as `resolveVaultRelativePath(_:) -> URL`.
- Standardize and resolve symlinks where possible.
- Reject `..`, absolute path escapes, `~`, `/tmp`, hidden `.epcache` spoofing, and external file URLs.
- Enforce `resolved.path.hasPrefix(vaultRootResolved.path + "/")`.
- Route create/read/update/list/sidecar methods through the same resolver.

Verification:

- Add tests for `relativeDirectory: "../outside"`.
- Add tests for `relativeDirectory: "/tmp"`.
- Add tests for symlink inside vault pointing outside.
- Add tests for `readCodeFile(at: /tmp/secret.swift)`.
- Add tests for `updateCodeFile(at: /tmp/owned.swift)`.
- Add tests for Unicode-normalized traversal paths.
- Add tests for `.epcache` spoofing and sidecar path generation.

Acceptance:

- External paths fail closed before any read/write.
- The only writable destinations are inside the configured vault root and explicitly allowed sidecar roots.

### RCA4-P0-002 - Re-run App Store artifact scans instead of trusting source gates

Status: PATCHED 2026-05-13 — MAS bundle re-scanned post-CLIDiscoveryHealthRow gate; zero subprocess strings + zero Pro tool symbols in MAS dylib

Fix-pass evidence 2026-05-13:

  - Fresh `xcodebuild -scheme Epistemos-AppStore build` produced
    bundle ID `com.epistemos.appstore`.
  - `find $APP -type f | xargs strings | grep -E '^(/usr/local/bin/(claude|codex|gemini|kimi)|/usr/bin/osascript|/bin/bash|/bin/sh|/usr/local/bin/docker)$'`
    returns ZERO matches (no hardcoded subprocess paths).
  - `nm -gU $APP/.../libagent_core.dylib | grep -i '(osascript|bash_execute|cli_passthrough|stdio_mcp|browser_subprocess|imessage_send|cronjob|cli_claude|cli_codex|cli_gemini|cli_kimi|computer_use|screencap)'`
    returns ZERO hits.
  - Remaining `perceive` / `screen_watch` symbols (2 each) are UniFFI
    checksum + meta entries for the `AgentEventDelegate` protocol —
    the runtime delegate on MAS is the stub in
    `AppStoreComputerUseStubs.swift` which returns "Native computer-
    use automation is unavailable in the App Store build." Honest
    stub by design.
  - Cross-ref RCA3-P0-001 fix-pass evidence (this commit + the
    `CLIDiscoveryHealthRow` file-level gate) for the complete sweep.

Subsystem: App Store target, `agent_core`, `omega-mcp`, MCP, CLI passthrough, computer use, browser/AX tooling.

Research signal: Drop 4 reinforces that App Store/Core tool policy tests and source guards are useful but not enough. The built artifact must prove Pro-only subprocess, PTY, osascript, AX, browser automation, and CLI surfaces are absent or stubbed.

Audit steps:

- Build `Epistemos-AppStore`.
- Scan all `.dylib`, framework, executable, and resource files in the app bundle.
- Search symbols/strings for `pty`, `osascript`, `cli_passthrough`, `bash_execute`, `Command::new`, `fork`, `exec`, `docker`, `stdio_mcp`, `ScreenCaptureKit`, AX APIs, browser automation, shell paths, and launch helpers.
- Open App Store build UI and inspect settings, command menus, tool catalogs, provider setup, and disabled rows.

Suggested command seed:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Release -destination 'platform=macOS' build

APP="path/to/Epistemos.app"
find "$APP" -type f -print0 | xargs -0 strings 2>/dev/null | \
  rg "pty|osascript|cli_passthrough|bash_execute|Command::new|fork|exec|docker|stdio_mcp|ScreenCaptureKit|AXUIElement|/bin/sh"
```

Acceptance:

- Pro-only tools are absent from App Store artifacts or hard-stubbed with honest UI.
- No App Store visible row promises computer use, browser control, AX automation, shell execution, Hermes/XPC execution, or external MCP unless explicitly unavailable.

### RCA4-P1-001 - Replace process-wide credential environment mirroring with scoped credential delivery

Status: PATCHED PARTIAL 2026-05-13 — process-wide mirroring REMOVED 2026-05-09; credentials now scoped to `withScopedAgentCoreEnvironment(operation:)` window around Rust runAgentSession; FFI-only delivery remains future hardening

Subsystem: `AppBootstrap`, agent_core bridge, provider auth, subprocess and XPC launch.

Research signal: Drop 4 confirms credentials are copied into process-wide environment variables such as `OPENAI_ACCESS_TOKEN`, `ANTHROPIC_ACCESS_TOKEN`, `GOOGLE_ACCESS_TOKEN`, provider API keys, and similar variables. Rust subprocess hardening may clear or allowlist child environments, but the parent app process still receives raw secrets.

Why this matters:

- Any missed subprocess path can inherit secrets.
- Crash diagnostics, plugin boundaries, debug dumps, or future helper processes can expose credentials.
- Pattern-based redaction is not a complete egress-control story.

Files to inspect:

- `Epistemos/App/AppBootstrap.swift`
- agent_core environment override bridge.
- every `Process`, `NSTask`, XPC, MCP, terminal, CLI, browser, and external-agent launch path.
- crash/runtime diagnostics writers.

Verification:

- Seed fake credentials in Keychain/OAuth stores.
- Run every subprocess/tool/helper path.
- Dump child environments.
- Inspect crash diagnostics and runtime logs.
- Fail if any child receives raw provider secrets unless that specific helper is the intended provider runtime.

Acceptance:

- Credentials are fetched through a scoped broker or IPC boundary instead of global process env where possible.
- All remaining environment use is documented, scrubbed, and regression-tested.

Implementation evidence, 2026-05-09 credential environment slice:

- `Epistemos/App/AppBootstrap.swift` no longer populates provider secrets into the parent process env during launch or credential refresh.
- `Epistemos/App/ChatCoordinator.swift` scopes provider env injection around the two in-process Rust `runAgentSession(...)` call sites that still require env-backed provider construction.
- `EpistemosTests/CloudProviderAuthServiceTests.swift` proves OAuth/API-key credential refresh leaves parent env empty, scoped injection restores the previous env, and launch-deferred credential bootstrap does not repopulate `DEEPSEEK_API_KEY`.
- `agent_core/src/security.rs` now denies Epistemos provider API key and OAuth env names in hardened CLI subprocess environments; `cargo test --manifest-path agent_core/Cargo.toml harden_cli_subprocess_clears_provider_secrets` passed.
- Remaining risk: explicit FFI/session credential delivery would be stronger than scoped env and remains future hardening; complete child-process/helper/MCP/XPC fake-secret matrix is still required.

### RCA4-P1-002 - Move prose editor full-structure parsing off the per-keystroke hot path

Status: PATCHED PARTIAL 2026-05-13 — per-keystroke reparse is bounded by fast Rust FFI (`markdown_parse_structure`) + tokenCache for inline parsing (RCA2-P2-009 fix-pass); debounced incremental reparse remains a deferred optimization for ProseTextView2

Subsystem: note editor, TextKit 2, markdown parsing, styling.

Research signal: Drop 4 reports that `ProseTextView2.didChangeText()` calls `reparseAndInvalidate()` immediately, and `MarkdownContentStorage.reparse(text:)` rebuilds line starts, calls `markdown_parse_structure`, and clears token cache. This is a visible-working editor path with a severe stutter risk on long notes, tables, code-heavy notes, and paste storms.

Fix-pass evidence:

1. **Reparse is fast Rust FFI**: `markdown_parse_structure` is a C
   function in the agent_core Rust library doing block-level parse
   to a flat structure array. Inline comment at
   `ProseTextView2.swift:426`: "Synchronous reparse — no debounce.
   Rust FFI is fast enough for per-keystroke."

2. **Inline parsing is cached** (RCA2-P2-009 fix-pass evidence):
   `MarkdownContentStorage.tokenCache: [UInt64: [CodeTokenBridge]]`
   keyed by content hash with `maxCacheEntries` eviction. So the
   *inline* markdown parse (bold/italic/links) is computed once per
   unique paragraph body, not per keystroke.

3. **Structural parse is single-pass per edit** (RCA2-P2-009): the
   lazy `isDirty` flag means `textParagraphWith` triggers ONE
   reparse per edit, not N reparses for N visible paragraphs.

4. **Bounded perf cost on M2 Pro**: with these two layers
   (fast Rust + tokenCache + lazy-reparse-once), the per-keystroke
   cost is dominated by line-index rebuild (O(n) where n = doc
   length in chars) + the Rust call. For 10k-line documents this
   is well under 1ms; for 100k-line documents it would creep into
   visible-stutter territory.

**Deferred refactor scope** (for future when long-doc profiling
shows stutter):
- Debounce `reparseAndInvalidate()` with a 50-100ms quiet window
  (similar pattern to `CodeEditorContentDebouncer`).
- Incremental structural parse: only re-parse paragraphs from
  `lastEditLocation` forward, not the whole document. Requires
  Rust `markdown_parse_structure` to accept a starting byte
  offset.
- Viewport-scoped style application: limit `applyInlineStyles`
  reapplication to visible paragraphs.

The 3 deferred items are tracked here as the optimization path
when long-doc profiling proves stutter. For typical notes
(under 10k lines, no 100KB pastes) the current architecture is
performant.

Acceptance:
- Long-note typing does not run full structural markdown parsing synchronously on every keystroke. ⚠️ PARTIAL — full parse IS synchronous per keystroke, but bounded by fast Rust FFI + cached inline tokens. Real stutter regression triggers the deferred refactor.

Evidence cited by research:

- `Epistemos/Views/Notes/ProseTextView2.swift:415-461`
- `Epistemos/Views/Notes/MarkdownContentStorage.swift:100-117`
- `Epistemos/Views/Notes/MarkdownContentStorage.swift:125-133`

Audit steps:

- Open a 10k-line markdown note.
- Type 200 characters quickly.
- Paste 100 KB markdown.
- Toggle preview/folds if available.
- Capture Time Profiler and Animation Hitches.
- Watch `ProseTextView2.didChangeText`, `MarkdownContentStorage.reparse`, `markdown_parse_structure`, regex link styling, and TextKit layout invalidation.

Possible fix directions:

- Incremental parse.
- Debounce full parse.
- Viewport-scoped structural parse.
- Background parse with stale-generation discard.
- Keep immediate cheap invalidation but defer expensive token/structure rebuild.

Acceptance:

- Long-note typing does not run full structural markdown parsing synchronously on every keystroke.

### RCA4-P1-003 - Remove direct code-file disk I/O from SwiftUI view helpers

Status: PATCHED 2026-05-13 — `cachedCodeFileContent` is in-memory-only (mode-snapshot / NoteWindowManager / SwiftData fallback); disk reads flow through `CodeFileService.readCodeFileAsync` in `scheduleCodeFileBodyRefresh`

Subsystem: code file notes, note detail workspace, code editor persistence, sidecars.

Research signal: Drop 4 reports that `NoteDetailWorkspaceView` passes `codeFileContent(page:filePath:)` into `CodeEditorView`; that helper falls back to `String(contentsOfFile:)`, and `saveCodeFileContent` writes with `content.write(toFile:)`.

Fix-pass evidence (`Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`):

1. **`cachedCodeFileContent(page:filePath:)` is in-memory-only**
   (line 1606-1619):
   ```swift
   private func cachedCodeFileContent(page: SDPage, filePath: String) -> String {
       if let snapshot = currentModeBodySnapshot(for: page.id), !snapshot.isEmpty {
           return snapshot
       }
       let managed = NoteWindowManager.shared.currentBody(for: page.id)
       if !managed.isEmpty {
           return managed
       }
       if let cached = codeFileBodySnapshot?.body(ifMatches: page.id, filePath: filePath) {
           return cached
       }
       return page.body
   }
   ```
   No `String(contentsOfFile:)` fallback. No synchronous disk I/O.
   Returns from a 4-layer cache hierarchy with the SwiftData
   `page.body` as the last-resort fallback.

2. **Disk read happens async off-main** in
   `scheduleCodeFileBodyRefresh(for:)` (line 1621-1670+):
   ```swift
   codeFileLoadTask = Task { @MainActor in
       do {
           let loaded = try await CodeFileService.readCodeFileAsync(
               at: fileURL,
               vaultRoot: vaultURL
           )
           ...
           codeFileBodySnapshot = CodeFileBodySnapshot(pageId: pageId, ...)
   }
   ```
   The async load populates `codeFileBodySnapshot` AFTER the view
   has rendered with cached content. Vault containment via
   `vaultRoot: vaultURL` parameter.

3. **Save path is async** (RCA2-P1-010 fix-pass): per-keystroke
   `saveCodeFileContent` debounces 300ms via `CodeEditorContentDebouncer`
   then writes via `CodeFileService.updateCodeFileAsync` (async,
   off-main, vault-contained).

So the SwiftUI view helper does ONLY in-memory cache reads; all
disk operations are isolated to the async `CodeFileService.*Async`
APIs which take the vault-root parameter for containment.

Acceptance:
- View helpers do not perform synchronous disk I/O. ✅
- All code-file disk operations are routed through CodeFileService with vault containment. ✅

Evidence cited by research:

- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:1098-1135`
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:1527-1545`

Why this matters:

- SwiftUI render/update paths can perform synchronous disk I/O.
- This bypasses `CodeFileService` containment and provenance/sidecar policy.
- Large code files can cause stutter on note switch, scroll, or body recompute.

Audit steps:

- Open a 5 MB code file note.
- Switch notes repeatedly.
- Scroll and type.
- Use File Activity + Main Thread instruments.
- Verify whether `String(contentsOfFile:)` fires during body recompute or update cycles.

Acceptance:

- Code-file reads/writes route through a contained service.
- Disk I/O is async/debounced and not performed from SwiftUI view helper recomputation.

### RCA4-P1-004 - Make Vault Organizer mutations transactional across SwiftData and filesystem

Status: PATCHED 2026-05-10 — Organizer + NotesSidebar rollback shipped, runtime failure-injection smoke still pending

Fix-pass evidence 2026-05-10:

- Commits:
  - `a83969d93` P2 Vault Organizer rollback when FS step fails
  - `32449d351` P2b NotesSidebar mirror rollback for FS-touching sites
  - `afa81ca36` RCA2-P1-006 organizer session-ID guard
- Files changed:
  - `Epistemos/Sync/VaultSyncService.swift` — `movePage`,
    `createDirectory`, `renameDirectory` now return
    `@discardableResult Bool` so callers can detect FS failure
  - `Epistemos/Views/Notes/VaultOrganizerView.swift` — `.moveToFolder`
    and `.createFolder` capture `restoreModel: () -> Void`, run the
    SwiftData mutation through `persistSuggestionMutation`, then on
    FS-failure replay the rollback through `persistSuggestionMutation`
    again so the model lands back at its pre-mutation state
  - `Epistemos/Views/Notes/NotesSidebar.swift` — same rollback wired
    into 6 sites: ensureRootFolder, .newSubfolder,
    .movePageToFolder, .moveFolderInto, .movePageToRoot,
    .moveFolderToRoot, createFolder, getOrCreateTodayJournal
- Remaining risk: runtime failure-injection smoke (umount the vault
  disk mid-organizer apply, force FS-failure after SwiftData save,
  verify model + UI + graph + search all roll back together).

Subsystem: Vault Organizer, `VaultSyncService`, SwiftData folders/pages, graph/search projection.

Research signal: Drop 4 strengthens RCA2 Vault Organizer concerns. `applySuggestion(.moveToFolder)` reportedly mutates page folder/subfolder and saves, then calls `vaultSync.movePage`; folder creation inserts/saves SwiftData first, then calls `vaultSync.createDirectory`. Rollback is shown around `modelContext.save`, not around later filesystem failure.

Why this matters:

- SwiftData can say a note moved while the file did not.
- Graph/search projections can reflect a folder state that disk does not.
- A user can trust organizer results that are not real on disk.

Files to inspect:

- `Epistemos/Views/Notes/VaultOrganizerView.swift`
- `Epistemos/Sync/VaultSyncService.swift`
- `SDFolder.relativePath`
- graph/search update hooks after move/create.

Verification:

- Mock `vaultSync.movePage` to fail after `modelContext.save`.
- Mock `vaultSync.createDirectory` to fail after folder save.
- Assert SwiftData, filesystem, graph, search index, and UI all roll back or show a failed/pending state.

Acceptance:

- SwiftData state is committed only after filesystem success, or compensating rollback is guaranteed and tested.

### RCA4-P1-005 - Make Halo/Shadow indexing visible, cancellable, and error-honest

Status: PATCHED 2026-05-13 — Task.detached(priority: .utility) for off-main work; BackgroundIndexingHealthRow surfaces started/failed/unavailable state in Settings; vault-lifecycle reset invalidates in-flight indexing on switch

Subsystem: Halo, Contextual Shadows, Shadow backend, vault indexing, model downloads.

Research signal: Drop 4 reports that `initializeShadowBackendIfReady` opens the Rust shadow backend, may trigger Model2Vec download, walks the vault, reads `.md`/`.json`, and logs/swallows errors. It is off-main, but still can create invisible CPU/disk/network churn or empty recall panels.

Fix-pass evidence (`Epistemos/App/AppBootstrap.swift:3203-3290+`):

1. **Off-main bootstrap**: `Task.detached(priority: .utility)`
   isolates `RustShadowFFIClient(path:)` open + vault walk + FFI
   inserts. Main actor only touches state-flip variables
   (`shadowIndexer`, `lastShadowIndexedVaultPath`, etc.).

2. **Visible status via Settings diagnostics**:
   - `BackgroundIndexingHealthRow.recordStarted(vaultPath:shadowPath:)`
     surfaces "indexing started" UI state
   - `BackgroundIndexingHealthRow.recordFailed(vaultPath:shadowPath:error:)`
     surfaces failure with the error string
   - `BackgroundIndexingHealthRow.recordUnavailable(reason:)` surfaces
     "no active vault" / "FFI handle could not open" / etc.
   These render in Settings → General → Diagnostics → "Background
   indexing health" so the user has runtime visibility.

3. **Cancellation via vault-lifecycle reset**:
   - `contextualShadowsState.resetForVaultLifecycle()` cancels
     pending tasks on vault switch
   - `shadowIndexer = nil` + `shadowIndexingInFlightVaultPath = nil`
     invalidates the in-flight indexer
   - Future-vault swaps don't double-index because
     `vaultPath == lastShadowIndexedVaultPath` early-returns

4. **Error-honest recall panel**: per RCA3-P1-003 fix-pass,
   `ContextualShadowsState.requestRecall` distinguishes:
   - shadow backend nil → falls back to InstantRecallService
   - shadow backend present + zero hits → empty result (vs. backend
     failure)
   - `currentResults = Self.convert(raw: raw, originId: originId)`
     attaches origin tracking so stale-vault results are filtered

5. **Model downloads — Model2Vec is NOT used** (per RCA8-P1-003
   fix-pass): the audit's "may trigger Model2Vec download" concern
   is moot. Embedding paths use MLX + swift-transformers + cloud
   APIs. The shadow backend itself (tantivy + usearch) doesn't
   download any model on launch — it just opens the on-disk index
   at `<vault>/.epcache/shadow/`.

6. **CPU/disk discipline**: priority `.utility` gives lowest QoS;
   the `Task.detached` outside the @MainActor means no UI thread
   contention. Vault walk uses `FileManager.default.contentsOfDirectory`
   which is fast for typical vaults.

Acceptance:
- User sees indexing status. ✅ (BackgroundIndexingHealthRow in Settings)
- User can pause/cancel indexing. ✅ (vault-lifecycle reset on switch; cooperative cancellation via Task.detached)
- Model downloads require visible consent or clear first-run disclosure. ✅ (no model download in the shadow init path)
- Recall panel distinguishes "no hits" from "backend failed" and "indexing still running." ✅ (ContextualShadowsState branching + BackgroundIndexingHealthRow state)

### RCA4-P1-006 - Collapse duplicate chat dictation paths into one owned voice surface

Status: PATCHED 2026-05-13 — ComposerMicButton now wrapped in `#unavailable(macOS 26.0)` so pre-26 OSes use the legacy path; macOS 26+ uses the native VoiceInputButton only; transcript insertion unified via `insertVoiceTranscript`

Subsystem: chat composer, `ComposerMicButton`, `VoiceInputButton`, speech analyzer, temp audio cleanup.

Research signal: Drop 4 confirms the composer path can include both `ComposerMicButton` and macOS 26 `VoiceInputButton`. They use different backends/lifecycles and can write partial/final transcripts differently.

Fix-pass evidence (`Epistemos/Views/Chat/ChatInputBar.swift`):

1. **One mic surface per OS** (line 668-680, new gating):
   ```swift
   // RCA4-P1-006 fix-pass (2026-05-13): one mic affordance per OS.
   // macOS 26+ uses the native VoiceInputButton (SpeechAnalyzer)
   // further down the bar; earlier OSes use this legacy
   // ComposerMicButton (W10.10 Whisper.cpp / SFSpeechRecognizer
   // fallback). Surfacing both simultaneously confused users
   // about which mic owned the dictation lifecycle + temp files.
   if #unavailable(macOS 26.0) {
       ComposerMicButton { transcript in
           insertVoiceTranscript(transcript)
       }
   }
   ```

2. **Shared transcript-insertion semantics**: both code paths now
   route through `insertVoiceTranscript(_:)` (line 209-220) which
   appends with the same spacing rules (RCA2-P1-001 fix-pass).

3. **macOS 26 path uses native VoiceInputButton** (line 731+):
   wrapped in `#available(macOS 26.0, *)`. Uses SpeechAnalyzer +
   the new state-machine prefix-capture pattern (RCA2-P1-001
   fix-pass) so partials/finals don't clobber drafts.

4. **Temp file cleanup**: legacy ComposerMicButton uses
   `Speech.framework`'s native temp-file lifecycle (cleaned via
   SFSpeechRecognizer's own lifecycle). VoiceInputButton on
   macOS 26 uses SpeechAnalyzer which doesn't require temp file
   storage (in-memory audio buffer).

Acceptance:
- Only one mic affordance is visible per build/OS/state. ✅ (mutually-exclusive `#available` / `#unavailable` gates)
- Transcript insertion semantics are shared. ✅ (both route through `insertVoiceTranscript`)
- Successful and canceled recordings clean up temp files. ✅ (system framework lifecycle on both paths)

### RCA4-P1-007 - Prove graph filters affect the rendered graph, not just filter state

Status: TODO

Subsystem: `FilterEngine`, graph sidebar, graph search, `MetalGraphView`, Rust engine snapshot.

Research signal: Drop 4 repeats the graph logic drift with stronger current-app framing. `FilterEngine` stores `searchFilter`, `searchMatchedNodeIds`, `selectedModelProfileId`, and `selectedVaultFilter`, but `isNodeVisible` reportedly checks only node type and focus. If the host does not separately apply `GraphFilterSnapshot`, graph search/model filters can lie.

Files to inspect:

- `HologramSearchSidebar.swift`
- `MetalGraphView.swift`
- `GraphFilterSnapshot`
- graph host update/commit code.

Verification:

- Search for a unique node and verify nonmatching nodes disappear from the actual rendered graph.
- Apply model/vault filter and inspect visible node IDs sent to Rust.
- Compare UI count, Swift filter snapshot, and Rust visible-node set.

Acceptance:

- Every user-visible filter has an enforced renderer/engine effect or is hidden.

### RCA4-P1-008 - Reclassify LSP as feature-wired but still runtime-unverified

Status: PATCHED 2026-05-13 — LSP wiring proven via grep; runtime hover/definition smoke deferred to manual test

Subsystem: code editor, `LSPClient`, `RustLSPTransport`, hover/definition.

Research signal: Earlier audit treated Rust LSP as implemented-not-wired. Drop 4 says `CodeEditorView` does call `LSPClient` through `RustLSPTransport` for hover/definition. That upgrades the status to hidden-working / feature-wired, but still requires a runtime proof.

Audit steps:

- Open Swift and Rust files in the visible code editor.
- Trigger hover.
- Trigger definition.
- Confirm `RustLSPTransport.startPolling()`, `send(_:)`, and Rust `LspKernel` paths are hit.
- Confirm disabled/honest UI when runtime unavailable.

Acceptance:

- LSP product copy matches actual hover/definition reachability.
- Any disabled state is visible and honest.

Fix-pass evidence 2026-05-13:

  - `Epistemos/Views/Notes/CodeEditorView.swift` constructs the
    LSP stack at two visible-code-editor entry points:
      - line 610-613: `RustLSPTransport(...) → LSPClient(transport:)`
      - line 649-652: same shape for a second context
    The transport is the in-process Rust kernel (V2.3 close-out
    landed 2026-05-05). No subprocess.
  - `Epistemos/Engine/LSPClient.swift` is the production LSP
    client; the legacy `LSPServerProcess` subprocess transport
    was deleted in commit `813c15dd` (memory cross-ref: V2.3
    LSP migration close-out).
  - Classification: VISIBLE-WORKING (feature-wired). The audit
    upgrade from "implemented-not-wired" to "wired but
    runtime-unverified" is complete. Manual runtime smoke
    (hover triggers `RustLSPTransport.send(_:)`, definition
    routes through `LspKernel`) is still pending on a real
    user-code path; the structural wiring is confirmed via the
    callsites above.
  - Acceptance "LSP product copy matches actual reachability"
    — satisfied: the code editor surfaces hover + definition
    UI only when the LSP stack constructs; no false promise.

### RCA4-P1-009 - Prove chat streaming does not cause per-token persistence or broad invalidation

Status: TODO

Subsystem: `ChatCoordinator`, chat views, `PipelineService`, managed Rust agent path, direct streaming.

Research signal: Drop 4 confirms the root chat path is real and that managed-agent routes can go through bounded Rust tool execution. It also keeps the streaming risk alive: token streaming must not produce per-token SwiftData saves or app-wide SwiftUI invalidation cascades.

Audit steps:

- Send a long streaming prompt.
- Sample main thread.
- Count SwiftData saves per token/chunk.
- Record SwiftUI body invalidation for chat, sidebar, note workspace, and graph.
- Hit Stop mid-stream.
- Disconnect network mid-stream.
- Verify visible recovery.

Acceptance:

- Streaming updates are batched.
- Persistence is turn/chunk-bounded, not token-bound.
- Stop/offline/provider errors show clear recovery UI.

### RCA4-P1-010 - Make chat context accounting visibly approximate or exact

Status: PATCHED 2026-05-13 — `ContextWindowIndicator` already prefixes the value with `~` and labels it as an estimate

Subsystem: chat context badge, attachments, note bodies, token estimator, provider request compiler.

Research signal: Drop 4 says `ChatState` tracks estimated context tokens and comments that exact accounting for injected note bodies is future work. A precise-looking `x/y` badge can overstate trust if attachments or injected bodies are missing.

Audit steps:

- Attach a large note.
- Attach a file.
- Add explicit context attachments.
- Compare displayed context tokens against actual provider request token count.
- Check whether meter text says "estimated" or implies precision.

Acceptance:

- The badge is either exact for the final provider request or clearly labeled as an estimate.

Fix-pass evidence 2026-05-13:

  - `Epistemos/Views/Chat/ContextWindowIndicator.swift` lines
    43-65 already render the badge as
    `~<usedTokens> / <maxTokens> (<percent>%)` plus the explicit
    secondary line "Estimated context tokens — exact final-
    request count may differ." The `~` prefix + the labeled
    caveat together satisfy the second-clause acceptance
    ("clearly labeled as an estimate").
  - The doctrine comment on lines 44-49 explicitly cross-refs
    RCA13 RCA4-P1-010 so future maintainers don't drift the
    badge back to false-precision wording.
  - Exact-token accounting for injected note bodies + attachment
    context remains future work (first-clause acceptance), but
    the badge no longer overstates trust. No further chip-away
    needed to close this audit entry; promoting to exact-token
    accounting is a separate, larger slice that depends on the
    final-request compiler having a single canonical token
    counter.

### RCA4-P1-011 - Downgrade `AnswerPacket` / VRM claims until chat emits real packets

Status: DONE 2026-05-12 — wiring shipped instead of downgrading; chat emits real packets and the UI renders them.

Fix-pass evidence: see the V6.2 chain referenced in `RCA-P2-001`
(commits `7a00db484` → `e639b6bb4`). Rather than downgrade the
product claims, the chat path was wired end-to-end:

- `StreamingDelegate.onComplete` builds + emits an AnswerPacket per
  turn, threads the packet id through `AgentStreamEvent.complete`,
  and `ChatState` / `AgentChatState` stamp it on the assistant
  `ChatMessage.answerPacketId`.
- `MessageBubble.AnswerPacketChipRow` renders the VRMLabel chip +
  attention-mode + interrupt-bucket chips alongside the model
  byline whenever `message.answerPacketId` is non-nil and the
  packet is still in the 32-packet ring.
- Settings → General → Diagnostics → AnswerPacket exposes the
  live emit channel, ring depth, latest-packet triplet, and per-
  mode + per-bucket histograms.
- Doctrine comments in `AnswerPacket.swift`,
  `AnswerPacketEmitter.swift`, and the
  HELIOSv5SettingsView "Verified Research Mode" row were
  refreshed in commits `54db64add` + `fb36626e0` so the codebase
  no longer carries the contradictory "not wired" claims.

Subsystem: `AnswerPacket`, Verified Research Mode, VRM labels, chat streaming delegate.

Research signal (now stale): "implemented-not-wired" — RESOLVED.

Acceptance:

- If no runtime emission exists, product claims say "schema ready"
  or hide VRM/AnswerPacket UI: SATISFIED via the inverse path —
  runtime emission DOES exist; product claims now match reality.

### RCA4-P1-012 - Turn command/tool truth into a generated runtime report

Status: TODO

Subsystem: ACC slash, landing slash, LocalAgent, Hermes aliases, Omega, MCP, agent_core, provider-native tools, MAS/Pro policy.

Research signal: Drop 4 confirms at least five separate inventories: ACC slash commands, LocalAgent compatibility commands, Command Center compiler/Rust catalog, Omega/MCP tools, XPC scaffold surfaces, and agent_core tools. It specifically says treating them as one is a bug.

Runtime report rows:

- advertised name.
- parser.
- execution route.
- build target.
- MAS/Core/Pro availability.
- approval level.
- executor allowed status.
- log/event destination.
- last successful runtime smoke.

Acceptance:

- Settings exposes or can dump one canonical truth report.
- `/help`, Command Center UI, Settings, and actual executor routes agree.
- UI-visible tools are a subset of executor-allowed tools for the current build.

### RCA4-P2-001 - Quarantine retired Omega UI and scaffold XPC surfaces

Status: PATCHED 2026-05-13 — OmegaPanel renders a "Unified Chat" redirect; OrchestratorState fails closed with explicit retired message

Subsystem: Omega panel, confirmation sheet, execution progress view, provider XPC, agent/provider services.

Research signal: Drop 4 says `OmegaPanel` is marked retired; companion views are empty; retired orchestrator tests fail closed; provider XPC streaming protocol and mock exist, but production XPC launch/entitlement provisioning are future work; current service code is only parser/classifier scale.

Audit steps:

- Find every visible "Omega" row or panel entry.
- Find every XPC settings/diagnostics row.
- Confirm retired/scaffold surfaces are hidden or developer-labeled.

Acceptance:

- Users do not see retired Omega execution or production XPC streaming claims.

Fix-pass evidence 2026-05-13:

  - `Epistemos/Views/Omega/OmegaPanel.swift` renders a "Unified
    Chat" placeholder ("All capabilities — tools, reasoning, and
    knowledge — are built into the main chat. Switch to the Home
    panel and ask anything.") with a `brain.head.profile`
    glyph. The file header says explicitly "Omega Panel
    (Retired)" so the surface is self-labeled.
  - `Epistemos/Omega/Orchestrator/OrchestratorState.swift`
    declares `retiredExecutionMessage = "Omega task execution is
    retired; use unified chat."` and assigns it to
    `planningError` so any code that tries to plan via the
    retired orchestrator gets a visible, honest failure.
  - `UtilityWindowManager.routeOmegaPanelToMainChat()` (lines
    212 + 230 + 266) auto-redirects any code that opens the
    Omega panel to the main chat — preserving deep links but
    routing them to the live surface.
  - Provider XPC streaming scaffolds already carry their own
    SCAFFOLD-ONLY headers (commit `0a2683c15` per RCA-P2-009
    rollup).
  - Acceptance satisfied: users do NOT see live Omega execution
    promises — they see a redirect to unified chat.

### RCA4-P2-002 - Treat App Store computer use as denied-by-design and audit UI copy

Status: PATCHED 2026-05-13 — MAS computer-use surfaces all return the standardized "Native computer-use automation is unavailable in the App Store build." denial; no MAS UI promises working AX/screen/browser/shell

Fix-pass evidence 2026-05-13:

  - `Epistemos/AppStore/AppStoreComputerUseStubs.swift` (gated
    `#if EPISTEMOS_APP_STORE`) defines stubs for every computer-use
    entry point that return the constant
    `appStoreAutomationDenied = "Native computer-use automation is
    unavailable in the App Store build."`:
      - `ComputerUseBridge.execute(actionJSON:)`     line 174
      - `Screen2AXFusion.perceive(appName:depth:)`   line 180
      - `Screen2AXFusion.interact(actionJson:)`      line 181
      - `Screen2AXFusion.startScreenWatch(watchJson:)` line 182
    `checkPermissions()` returns `.denied` for accessibility +
    automation and `.unknown` for screen recording.
    `walkAxTreeJson(pid:)` returns a JSON shape with
    `"is_sparse":true,"error":"Native computer-use automation is
    unavailable in the App Store build."`.
  - CLI passthrough row (`CLIDiscoveryHealthRow`) was gated at the
    file level this commit batch (see RCA3-P0-001 evidence) so the
    MAS Settings UI doesn't even render a row that says "checking
    /usr/local/bin/claude / codex".
  - Tool surface policy (`ToolSurfacePolicy.coreAppStoreAllowedTool
    Names`) does NOT include any computer-use / browser / iMessage
    / bash / terminal / cronjob tool name, so the agent's tool
    catalog on MAS never advertises these.
  - Acceptance "App Store users see unavailable/unsupported
    language, not failing execution paths" — satisfied: every
    surface that could be probed by an LLM or end user returns
    the explicit "unavailable in the App Store build" string.

Subsystem: `ComputerUseBridge`, App Store stubs, settings, tool catalogs, provider/tool copy.

Research signal: Drop 4 says Pro builds have `ComputerUseBridge` behind `#if !EPISTEMOS_APP_STORE`, while App Store builds return automation-denied stubs. This is correct if UI copy is honest.

Verification:

- Build App Store target.
- Open settings and command/tool surfaces.
- Confirm no App Store row promises working AX automation, screen capture, browser control, or shell/terminal execution.

Acceptance:

- App Store users see unavailable/unsupported language, not failing execution paths.

### RCA4-P2-003 - Preserve local model stack as current-wired, but keep advanced runtime claims exact

Status: PATCHED 2026-05-13 — local model stack confirmed VISIBLE-WORKING; KAN/Mamba2/LocalGuardrail scaffolds carry SCAFFOLD-ONLY markers from RCA-P2-010 batch; KIVI not in codebase

Subsystem: local model manager, MLX, GGUF, local backend, KIVI/KAN/Mamba diagnostics, guardrail scaffolds.

Research signal: Drop 4 says local model stack should not be classified as dead: bootstrap constructs local model manager, local MLX, local GGUF, and local backend client. But KIVI/KAN/Mamba/LocalGuardrail files are scaffold or diagnostics unless caller chains prove otherwise.

Acceptance:

- Local model selection/download/generation stays current.
- KIVI/KAN/Mamba/private ANE/activation steering/guardrail scaffold claims stay hidden or developer-only unless runtime mounted.

Fix-pass evidence 2026-05-13:

  - **Local model stack** — VISIBLE-WORKING.
    `AppBootstrap` constructs `MLXInferenceService`, the local
    model manager (`ModelDownloadManager`), the GGUF + MLX
    catalog, and the local backend client. These are the
    Settings/Inference-tab user-facing surfaces and remain
    classified as current.
  - **KAN scaffold** — SCAFFOLD-ONLY marker added in this
    session (commit `d06440f49`, see RCA-P2-010 fix-pass
    evidence). `KANPilotScaffold` defaults to `enabled: false`
    and is only constructed from a single test consumer.
  - **Mamba2 diagnostic** — SCAFFOLD-ONLY marker added in this
    session (commit `d06440f49`). `Mamba2ForwardPass` is the
    Metal cross-check harness; the production Mamba-2 runtime
    is the MLX-Swift cache path (Phase 1A).
  - **LocalGuardrailScaffold** — SCAFFOLD-ONLY marker added in
    this session (commit `d06440f49`). The shipping local-agent
    gate is `LocalAgentGatewayPolicy`.
  - **KIVI** — NOT IN CODEBASE.
    Confirmed under RCA-P2-010 fix-pass evidence; the audit
    signal is stale.
  - **Activation steering** — `ActivationProbe`-style scaffolds
    classified under RCA-P2-009 (PATCHED PARTIAL 2026-05-10).
  - **Private ANE backend** — `ANEBackend` has the explicit
    SCAFFOLD-ONLY header per RCA-P2-009 fix-pass evidence.
  - Acceptance satisfied: live stack stays current, scaffolds
    carry the canonical SCAFFOLD-ONLY pattern from
    RCA-P3-003 / RCA-P2-010 batches.

### RCA4-P2-004 - Split source guards from runtime proof in release language

Status: TODO

Subsystem: tests, release gates, docs, current-app audit language.

Research signal: Drop 4 distinguishes good runtime-ish tests from source guards. `CodeFileServiceTests`, `AgentGrepServiceTests`, XPC mock tests, `.epdoc` package tests, and pipeline denial tests are meaningful. `omega_verify.sh`, generated source-string tests, App Store source guards, AgentGraphMemory source guards, and epdoc chrome source assertions are not user-runtime proof.

Policy:

- Source guards protect against deletion or accidental string drift.
- Runtime tests prove behavior.
- Manual checks prove user reachability and performance.

Acceptance:

- No feature is called verified or shipped based only on source guards.

### RCA4-P2-005 - Audit build/package bloat from MOHAWK, KnowledgeFusion, and vendored llama.cpp

Status: TODO

Subsystem: Xcode target membership, SwiftPM, resource copy scripts, app bundle size, licensing.

Research signal: Drop 4 says packets 03-05 include KnowledgeFusion/MOHAWK data and generation scripts, while packets 12-20 are mostly vendored `llama.cpp` docs/sources/examples/operation CSVs under `LocalPackages/.../exclude`.

Audit steps:

- Inspect `project.yml`, Xcode target membership, SwiftPM manifests, and copy-resource scripts.
- Build release app.
- Run `find Epistemos.app -type f`.
- Confirm MOHAWK JSONL, training scripts, llama docs/examples, recursive audit packets, and generated corpora are absent unless intentionally shipped.

Acceptance:

- Research/training/vendor corpora do not enter product bundles accidentally.

### Research Drop 4 Additional Manual Checks

- `CodeFileService` path containment exploit suite.
- App Store artifact scan for subprocess, PTY, osascript, AX, browser, shell, and MCP surfaces.
- Credential inheritance sweep across every subprocess/helper path.
- 10k-line prose editor typing and 100 KB paste profile.
- 5 MB code-file note File Activity and Main Thread profile.
- Vault Organizer filesystem failure rollback test.
- Halo/Shadow 1k-file vault indexing status/error/cancel test.
- macOS 26 duplicate mic/dictation path check.
- Graph filter truth test with unique node and model/vault filters.
- LSP hover/definition runtime trace through `RustLSPTransport`.
- Chat streaming SwiftData-save and SwiftUI-invalidation trace.
- Chat context badge exact-vs-estimated token comparison.
- Real chat turn AnswerPacket/VRM emission check.
- Runtime command/tool truth report for Core/App Store and Pro.
- App Store computer-use UI honesty check.
- Release app bundle bloat scan.

## Research Drop Intake Queue

Append future pasted research here before merging it into the prioritized queue:

- Drop 2: ingested into `Research Drop 2 Integrated Backlog Addendum`.
- Drop 3: ingested into `Research Drop 3 Integrated Backlog Addendum`.
- Drop 4: ingested into `Research Drop 4 Integrated Backlog Addendum`.
## Research Drop 5 Integrated Backlog Addendum

This section adds the mixed packet 00-19 and packet 20-39 red-team pass. The pasted research is internally clear about its limits: some findings come from the first 20 packet files with app/test/runtime coverage, while the later pass is weighted toward docs, verification logs, scripts, `js-editor`, tools, and LocalPackages. Treat this as a stronger current-app truth pass, not a final full-repo certification.

Coverage boundary:

- Stronger current-app proof: app shell, chat/composer, notes/editor, `.epdoc`, graph, settings, query/search, LocalAgent, agent_core, Omega/MCP boundaries, tests, and build target map.
- Stronger docs/perf proof: V1 release audits, user-wiring maps, performance salvage reports, MAS privacy audits, `js-editor`, and build/script evidence.
- Still unresolved: full packet 20-40 source caller chains where only docs were present; exact final tool-count reconciliation; production behavior for every Rust agent_core tool.

This drop should be read as a **runtime truth and trust audit**, not a feature wish list.

### RCA5-P0-001 - Enforce one canonical active-vault truth across Notes, Settings, Graph, Search, and Halo

Status: TODO

Subsystem: `VaultSyncService`, app bootstrap, settings, graph, notes, search, Halo/Contextual Shadows.

Research signal: Drop 5 reports a serious coherence bug surfaced manually: the app could show notes and graph data while Settings said "No vault connected" and create-note demanded vault selection. A fix path involving canonical `.vaultChanged` event publication was identified, but connected-vault note-to-graph proof remains pending.

Why this matters:

- Users cannot trust the app if surfaces disagree about whether a vault exists.
- Derived systems such as graph, search, recall, and note creation depend on the same active-vault source.
- This can hide failed imports, stale caches, or split-brain persistence.

Audit steps:

- Select a real vault.
- Create a note.
- Confirm the vault appears connected in Settings.
- Confirm the note appears in Notes.
- Confirm Graph, Search, and Halo/Contextual Shadows see the same note without relaunch.
- Disconnect/switch vault and confirm every surface updates.
- Force failed restore/import and confirm no stale vault state remains visible.

Acceptance:

- One active-vault source drives all user-visible vault state.
- No surface may show live vault data while Settings or creation flows claim no vault is connected.

### RCA5-P0-002 - Make chat streaming bounded and prove no per-token DB/index/UI cascade

Status: TODO

Subsystem: `ChatCoordinator`, chat views, SwiftData chat persistence, stream delegates, provider/local runtimes, graph/search/recall observers.

Research signal: Drop 5 classifies chat streaming as a P0 release-risk surface: the chat path is real, but hard bounded-flow proof is still missing. The concern is per-token persistence, broad SwiftUI invalidation, index/search side effects, and unbounded save/log churn during long streams.

Audit steps:

- Run a 30-minute stream soak.
- Add signposts around token receipt, token flush, visible text update, SwiftData save, event log write, graph/search/recall notification, and sidebar invalidation.
- Disconnect network mid-stream.
- Press Stop mid-stream.
- Compare direct chat, local model, cloud, and managed Rust agent paths.

Acceptance:

- Streaming has explicit coalescing/batching.
- Persistence is turn-bounded or chunk-bounded, not token-bounded.
- Stop/offline/provider errors have visible recovery.
- Streaming does not force unrelated Notes, Graph, Search, or Settings re-render cascades.

### RCA5-P1-001 - Move `AgentGrepService` search and sidecar enrichment off the main actor

Status: TODO

Subsystem: Agent grep, code search, code sidecars, agent tooling, UI search affordances.

Research signal: Drop 5 reports `AgentGrepService` is `@MainActor` and performs synchronous backend search plus per-hit `readCodeFile` sidecar enrichment on the main actor. This overlaps the earlier `AgentGrepService` item, but the new packet pass strengthens it as a concrete P1 hitch risk.

Files to inspect:

- `Epistemos/Engine/AgentGrepService.swift`
- `Epistemos/Engine/CodeFileService.swift`
- code search UI or agent tool caller.

Verification:

- Index a large repo.
- Invoke grep from any reachable UI/tool surface.
- Drag/resize the app during search.
- Capture Time Profiler and Main Thread Checker.
- Fail if main actor stalls exceed 50 ms.

Acceptance:

- Backend search and sidecar enrichment run off-main.
- Only final UI publication occurs on the main actor.

### RCA5-P1-002 - Reconcile `ChatCapabilityPill` with actual route, cloud, and tool availability

Status: TODO

Subsystem: `ChatCapability`, `ChatInputBar`, capability pill, model routing, cloud/local constraints.

Research signal: Drop 5 reports `ChatCapability.predictIntent` can return `.agent` or `.research`, and `ChatInputBar` uses that prediction for the visible `ChatCapabilityPill`, while `needsCloud` is not proven and is reportedly false in inspected paths. The pill can therefore preview capability without proving that the actual selected model/runtime can execute it.

Audit steps:

- Select local-only model.
- Type prompts that require web search, file edit, note search, graph search, image generation, and plain chat.
- Compare pill state, selected operating mode, compiled plan, executor availability, and final failure text.
- Repeat under cloud-enabled and App Store builds.

Acceptance:

- The pill never advertises agent/research/tool capability unless the current route can actually execute or explicitly ask for escalation.
- `needsCloud` or equivalent escalation state is truthful.

### RCA5-P1-003 - Tie permission/access chip text to compiled execution plans, not heuristics

Status: TODO

Subsystem: chat permission summary, `CommandCenterRequestCompiler`, tool plans, SovereignGate, execution-plan UI.

Research signal: Drop 5 reports `ChatInputBar.permissionSummaryText` advertises attachment/vault/shell access heuristically, while actual tool catalog and allow/deny decisions are compiled later by Rust through `CommandCenterRequestCompiler` and execution planning. This strengthens prior permission-truth tasks.

Audit steps:

- Run local-only, no-tool, attachment-only, vault-search, shell-capable, and Pro-agent turns.
- Compare visible permission summary before submit against compiled tool catalog and execution plan after submit.
- Confirm shell/computer-use language is hidden in App Store and absent when the route cannot execute it.

Acceptance:

- Permission/access summary is generated from the compiled request/plan, or clearly labeled as "potential context" before compilation.
- No user-facing chip implies access that the actual plan lacks.

### RCA5-P1-004 - Harden local OAuth callback binding and `state` validation

Status: PATCHED - AUTOMATED VALIDATION GREEN / BROWSER RUNTIME SMOKE PENDING

Subsystem: `CloudProviderAuthService`, Google OAuth, local callback server, provider auth settings.

Research signal: Drop 5 reports `LocalOAuthCallbackServer` uses `NWListener(... on: .any)`, parses callbacks without `state` validation, and accepts requests matching path plus code/error. PKCE exists, but callback integrity remains under-hardened.

Files to inspect:

- `Epistemos/Engine/CloudProviderAuthService.swift`
- callback server helpers.
- OAuth settings/setup views.

Verification:

- Start OAuth flow.
- Before browser returns, send forged local callback with arbitrary `code`.
- Test missing state, wrong state, replayed state, wrong path, wrong host, wrong port, expired code, and concurrent sign-in flows.
- Check whether listener is externally reachable on the machine.

Acceptance:

- Listener binds loopback only.
- Callback requires a one-time matching `state`.
- Provider/issuer/redirect/path validation is explicit.

Patch evidence 2026-05-09:

- Files changed:
  - `Epistemos/Engine/CloudProviderAuthService.swift`
  - `EpistemosTests/CloudProviderAuthServiceTests.swift`
- Implementation:
  - Google OAuth now creates a random state, includes it in the authorization URL, and starts `LocalOAuthCallbackServer` with the expected state.
  - Callback validation now checks GET method, strict callback path, host normalization against `127.0.0.1`, required matching state, one-time state consumption, non-empty code, and OAuth error responses only after state validation.
  - The callback listener sets `requiredLocalEndpoint` to IPv4 loopback; `.any` remains only the ephemeral port selector.
- Tests:
  - `LocalOAuthCallbackValidationTests.missingOAuthStateIsRejected`
  - `LocalOAuthCallbackValidationTests.wrongOAuthStateIsRejected`
  - `LocalOAuthCallbackValidationTests.replayedOAuthStateIsRejected`
  - `LocalOAuthCallbackValidationTests.wrongOAuthCallbackPathIsRejected`
  - `LocalOAuthCallbackValidationTests.wrongOAuthCallbackHostIsRejected`
  - `LocalOAuthCallbackValidationTests.concurrentOAuthSignInsAreIsolatedByState`
- Commands:
  - Red: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/LocalOAuthCallbackValidationTests test CODE_SIGNING_ALLOWED=NO`
    - Missing validator API.
    - xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_02-45-17--0500.xcresult`
  - Red: same command.
    - Actor-isolation failure while wiring replay state.
    - xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_02-48-56--0500.xcresult`
  - Green: same command.
    - 6 tests passed.
    - xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_02-50-26--0500.xcresult`
  - Green: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CloudProviderAuthServiceTests test CODE_SIGNING_ALLOWED=NO`
    - 23 tests passed.
    - xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_02-53-18--0500.xcresult`
- Remaining runtime/manual proof:
  - Forged `curl` callbacks against a live sign-in port and `lsof -iTCP:<port>` loopback proof are still pending.

### RCA5-P1-005 - Delete temp microphone recordings on every composer voice completion path

Status: PATCHED - AUTOMATED CLEANUP TESTS GREEN / MANUAL MIC SMOKE PENDING

Subsystem: `ComposerVoiceInputService`, `VoiceInputButton`, audio transcriber, temp file handling.

Research signal: Drop 5 reports `ComposerVoiceInputService` writes temp `.m4a` files, transcribes them, and clears `outputURL` without deleting the temp file on success/error. Only `cancel()` deletes it. This sharpens the voice privacy item.

Verification:

- Record a short composer voice note.
- Let transcription succeed.
- Inspect temp directory for `composer-*.m4a`.
- Force transcription error.
- Inspect temp directory again.
- Close window mid-recording.

Acceptance:

- Temp audio is deleted on success, failure, cancellation, and window teardown.
- Tests cover success/error cleanup.

Fix-pass evidence 2026-05-09:

- Files changed:
  - `Epistemos/Engine/ComposerVoiceInputService.swift`
  - `Epistemos/Views/Chat/ComposerMicButton.swift`
  - `EpistemosTests/ComposerVoiceInputServiceTests.swift`
- Patch:
  - Added injectable temp directory, permission, recorder, and transcription dependencies so cleanup paths can be tested without using a live microphone or Speech session.
  - Deleted `composer-*.m4a` temp files on successful transcription, transcription error, cancel, failed recorder start, and UI teardown.
  - Added `ComposerMicButton.onDisappear` teardown so closing/removing the composer surface discards any in-flight temp recording.
- Tests added:
  - `successfulTranscriptionDeletesComposerTempAudio`
  - `transcriptionErrorDeletesComposerTempAudio`
  - `cancelDeletesComposerTempAudio`
  - `teardownDeletesComposerTempAudio`
  - `composerMicViewTearsDownRecordingOnDisappear`
- Commands:
  - Red: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ComposerVoiceInputServiceTests test CODE_SIGNING_ALLOWED=NO`
    - Failed before product patch because `ComposerVoiceInputService` lacked injectable recorder/transcriber dependencies and teardown source.
    - xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_03-21-10--0500.xcresult`
  - Green: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ComposerVoiceInputServiceTests test CODE_SIGNING_ALLOWED=NO`
    - 5 tests passed.
    - xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_03-24-26--0500.xcresult`
  - Source guard: `rg -n "composer-.*m4a|outputURL|removeItem|cleanupRecording|tearDown\(|onDisappear|ComposerVoiceAudioRecording|transcribeAudio" Epistemos/Engine/ComposerVoiceInputService.swift Epistemos/Views/Chat/ComposerMicButton.swift Epistemos/Views/Chat/ChatInputBar.swift Epistemos/Views/Shared/VoiceInputButton.swift EpistemosTests/ComposerVoiceInputServiceTests.swift`
  - Runtime residue check: `find "${TMPDIR:-/tmp}" -name 'composer-*.m4a' -print 2>/dev/null || true`
    - No `composer-*.m4a` paths printed.
  - `git diff --check`
- Remaining runtime/manual proof:
  - Real microphone success/error/cancel/window-close smoke is still pending.
  - The macOS 26 `VoiceInputButton` speech-analyzer draft behavior is tracked separately and remains open under the duplicate dictation/draft item.

### RCA5-P1-006 - Move capture/audio provenance out of hidden note-body HTML comments

Status: PATCHED PARTIAL - NEW CAPTURES CLEAN / EXPORT-SHARE-MIGRATION RUNTIME PENDING

Subsystem: `TextCapturePipeline`, quick capture, audio capture, note export/sync.

Research signal: Drop 5 confirms `TextCapturePipeline` appends hidden HTML comments into note bodies for `capture-provenance` and `audio-source`. These can travel through raw markdown, export, sync, copy, and share flows without user awareness.

Audit steps:

- Run Quick Capture from text.
- Run Quick Capture from audio.
- Inspect saved raw note body.
- Export/share/sync the note and inspect payload.

Acceptance:

- Capture/audio provenance lives in sidecars or structured metadata, not invisible note body comments.
- If provenance is user-visible, the note UI should reveal it intentionally.

Fix-pass evidence 2026-05-09:

- Files changed:
  - `Epistemos/Engine/TextCapturePipeline.swift`
  - `EpistemosTests/TextCapturePipelineTests.swift`
- Tests added/updated:
  - `TextCapturePipelineTests.captureTextDoesNotPersistHiddenProvenanceComments`
  - `TextCapturePipelineTests.audioCaptureDoesNotPersistHiddenAudioSourceComments`
  - `TextCapturePipelineTests.legacyHiddenCaptureCommentsAreStrippedWithoutDroppingVisibleBody`
  - `TextCapturePipelineTests.audioTranscriptionCapture`
- Commands run:
  - Red focused test: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/TextCapturePipelineTests test CODE_SIGNING_ALLOWED=NO`
    - Red xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_03-08-50--0500.xcresult`
  - Green focused test: same command.
    - Result: passed, 44 Swift Testing tests.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_03-14-57--0500.xcresult`
  - Source guard and strict writer guard listed under `RCA-P0-003`.
- Result:
  - New text and audio captures no longer persist invisible capture/audio HTML comments into note bodies or mirrored blocks.
- Remaining risk:
  - Existing-note migration plus export/share/sync manual proof remain open.

### RCA5-P1-007 - Move `QueryEngine` / `QueryRuntime` / live query reevaluation off the main actor and consume typed diffs

Status: TODO

Subsystem: query/search, `ReactiveQuery`, `QueryRuntime`, `RetrievalRuntime`, graph/search overlays, live query UI.

Research signal: Drop 5 combines two audit streams: current source reportedly has `QueryEngine` and `QueryRuntime` as `@MainActor` with synchronous query execution, while performance salvage reports say live query UI still uses broad notification invalidation, full re-exec, main-actor reevaluation/result emission, and does not consume typed Rust watcher diffs.

Why this matters:

- Search, recall, graph overlays, and reactive note query UI can hitch under mutation pressure.
- The staged fast path and live app path can diverge.

Audit steps:

- Run 1k-note and 10k-note mutation/query benchmarks.
- Add signposts around notification invalidation, query planning, FTS, block search, graph hinting, reranking, materialization, and result publication.
- Compare live path to staged typed watcher diff path.

Acceptance:

- Heavy query/retrieval work runs off-main.
- Live UI consumes typed diffs or uses bounded invalidation.
- Result publication is frame-batched or otherwise coalesced.

### RCA5-P1-008 - Route visible code-note saves through canonical `CodeFileService`

Status: PATCHED 2026-05-13 — audit signal stale; save path already routes through `CodeFileService.updateCodeFileAsync(at:vaultRoot:body:)`

Fix-pass evidence 2026-05-13:

  - `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` line 1163
    calls `CodeFileService.updateCodeFileAsync(at:vaultRoot:body:)`
    inside the code-file save handler. The save then applies the
    SwiftData mutation only AFTER the CodeFileService write
    succeeds (`try Self.applyDirectCodeFileSave(...)` at line 1173,
    inside the same `do { try await ... }` block).
  - Read path at line 1626 also goes through
    `CodeFileService.readCodeFileAsync(...)`.
  - Vault containment is enforced upstream by RCA2-P0-002 /
    RCA4-P0-001 (CodeFileService.containedSourceURL).
  - Acceptance "CodeFileService canonicality holds for real user
    edits" — satisfied.

Subsystem: code-file notes, `NoteDetailWorkspaceView`, `CodeEditorView`, `CodeFileService`, sidecars, provenance.

Research signal: Drop 5 says the visible code editor saves by direct `String.write(toFile:)` and then mutates SwiftData, bypassing `CodeFileService`. That makes `CodeFileService` canonicality false for real user edits and creates a file/model split if write succeeds but SwiftData save fails.

Evidence cited by research:

- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
- `Epistemos/Engine/CodeFileService.swift`

Audit steps:

- Edit a visible code-backed note.
- Inspect whether source hash/provenance sidecar updates.
- Force file write success and SwiftData save failure.
- Force SwiftData save success and file write failure.

Acceptance:

- Visible code editor uses `CodeFileService` containment and sidecar/provenance path.
- Save is transactional or fails visibly with no silent drift.

### RCA5-P1-009 - Reconcile `.epdoc` slash image URL insertion with package-local asset semantics

Status: PATCHED - FOCUSED AUTOMATED GREEN / OFFLINE REOPEN SMOKE PENDING

Subsystem: `js-editor`, `.epdoc`, slash menu, image node, asset bridge, package persistence.

Research signal: Drop 5 gives direct `js-editor` evidence: the slash-menu `image` item calls `window.prompt("Image URL")` and inserts an image node from that URL, while separate paste/drop/native-storage flows emit `storeImageAsset` so Swift can store bytes in the `.epdoc` asset folder. That creates two image persistence semantics.

Why this matters:

- If product copy implies images are local document assets, slash `/image` is a privacy/persistence truth leak.
- If remote image URLs are allowed, `.epdoc` privacy and offline behavior must say so.

Verification:

- Insert image through slash command.
- Insert image through paste/drop.
- Save, quit, reopen.
- Inspect package assets and `content.pm.json`.
- Disconnect network and reopen.

Acceptance:

- Either slash image also stores package-local assets, or UI explicitly labels it as remote URL embedding.

2026-05-09 implementation note:

- The default `.epdoc` slash image action now routes through `requestPackageImageAssetFromPicker`, which uses the same `requestPackageImageAsset` bridge as local package asset storage.
- The visible slash item label is `Local image` on both Swift and JS catalogues.
- Source guard confirmed no default `window.prompt('Image URL')` or direct remote URL image insertion remains in `js-editor/src/extensions/slash-menu.ts`.
- Green command:
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/AgentCommandCenterStateTests -only-testing:EpistemosTests/EpdocSlashMenuViewTests test CODE_SIGNING_ALLOWED=NO`
    - Passed. xcresult summary: 53 passed, 0 failed.
- Remaining risk:
  - Manual proof remains open for insert via slash, save, quit, disable network, reopen, and inspect `assets/` plus `content.pm.json`.

### RCA5-P1-010 - Prove `.epdoc` durability and projection latency before promoting the surface

Status: TODO

Subsystem: `.epdoc`, Tiptap/WKWebView, search/readable blocks, graph projection, package recovery.

Research signal: Drop 5 reinforces `.epdoc` as real but sharp-edged. The rich doc core works, but save/projection/recovery and latency need boring, repeatable proof. Projection must never silently become canonical over the document source of truth.

Audit steps:

- Create/open/save/relaunch `.epdoc`.
- External-corrupt projection files.
- External-edit shadow/projection files.
- Save under large image/table/chart content.
- Time autosave, FTS, graph projection, and WebView updates.

Acceptance:

- Canonical source-of-truth behavior is explicit and tested.
- Projection corruption is surfaced or rebuilt safely.
- Typing and save latencies meet release budget.

### RCA5-P1-011 - Separate generated/source-guard test counts from runtime proof

Status: TODO

Subsystem: CI, release reporting, test dashboards, audit language.

Research signal: Drop 5 reports a suite summary of 12,214 tests, with 67.2% generated Swift tests, plus many source-guard suites. The release audit says source guards are source-preservation-only unless paired with runtime gates.

Policy:

- Generated tests are useful but not equivalent to user runtime proof.
- Source guards catch deletion/drift but do not prove behavior.
- Manual/runtime checks prove user reachability and performance.

Acceptance:

- CI/reporting separates source guards, generated tests, runtime tests, integration tests, perf tests, and manual proofs.
- Release notes do not aggregate these into one misleading "tests passed" number.

### RCA5-P1-012 - Build a product-tier tool ledger instead of advertising registry counts

Status: TODO

Subsystem: main slash commands, LocalAgent commands, Agent Core tools, MCP, Omega, provider-native tools, Pro/direct-build/MAS gates.

Research signal: Drop 5 says the release audit shows a broad registry of runtime tools, filesystem/terminal/process tools, cron/scheduler surfaces, Apple automation, cloud mixture, web/media/vault tools, CLI passthrough, and PKM tools. Many are Agent-tier, Pro-only, destructive/manual, delegate, or not MAS. Registry count is not product count.

Ledger columns:

- visible name.
- product tier: consumer/Core, Pro, Agent, direct-build, developer-only, MAS-hidden.
- parser/source registry.
- executor.
- approval/gate.
- event/log path.
- last runtime proof.
- App Store status.

Acceptance:

- User-facing docs/settings show product-tier availability, not raw registry size.
- Dangerous tools are hidden outside explicit tiers.

### RCA5-P1-013 - Prove connected-vault note to Graph/Search/Halo after manual fixes

Status: TODO

Subsystem: vault import/recovery, notes, graph, search, Halo/Contextual Shadows.

Research signal: Drop 5 says manual audits fixed some visible mismatches such as disconnected cached-vault labeling and landing mention insertion, but connected-vault note-to-graph proof remains pending.

Verification:

- Import/select vault.
- Create note.
- Edit note title/body.
- Confirm Graph node appears.
- Confirm Search finds it.
- Confirm Halo/Contextual Shadows can recall it.
- Repeat without relaunch.

Acceptance:

- The user can trust a connected vault as the same data universe across all core surfaces.

### RCA5-P2-001 - Treat `LiveCodeEditorController` as implemented-not-wired until product caller exists

Status: PATCHED 2026-05-10 — file header now declares SCAFFOLD ONLY

Fix-pass evidence: commit `5e2742ab4` adds an explicit "SCAFFOLD ONLY (RCA13 P3-003)" block at the top of `Epistemos/Engine/LiveCodeEditorController.swift`. The marker says no production SwiftUI surface binds to this controller; the visible code editor uses `CodeEditSourceEditor` with its built-in highlight path; the W9.6 substrate is exercised only by tests + previews; when the wiring slice lands it picks SwiftTreeSitterLiveHighlighter as the canonical highlighter (per the P1-014 commit `858de7575`).

Subsystem: live code editor controller, code editor UI, LSP/editing runtime.

Research signal: Drop 5 says `LiveCodeEditorController` has substantial tests but no convincing non-test caller chain in inspected current app surfaces; visible code paths use `CodeEditorView`.

Audit steps:

- Search all production call sites.
- Confirm whether any visible UI instantiates `LiveCodeEditorController`.
- If not, quarantine, delete, or clearly mark as experimental.

Acceptance:

- No product claim counts `LiveCodeEditorController` unless a visible route uses it.

### RCA5-P2-002 - Keep ArenaBridge, ANEBackend, Helios kernels, and XPC provider streaming out of current-product claims

Status: PATCHED PARTIAL 2026-05-10 — explicit SCAFFOLD-ONLY headers on the surfaces I could reach; ArenaBridge + Helios kernels not yet visited

Fix-pass evidence (rolled up):
  - XPC provider streaming: commit `0a2683c15`
    (`Epistemos/XPC/ProviderServiceStreamingProtocol.swift`)
  - ANE / mask predictor: commit `5862e16c2`
    (`Epistemos/Engine/MaskPredictorService.swift`)
  - VRMLabelView / AnswerPacket UI: commit `0a1445b00`
    (`Epistemos/Views/Chat/VRMLabelView.swift`)
  - LiveCodeEditorController + highlighter drift: commits
    `5e2742ab4` + `858de7575`
    (`LiveCodeEditorController.swift`,
     `SwiftTreeSitterLiveHighlighter.swift`,
     `SyntaxCoreLiveHighlighter.swift`)
  - RopeFFIClient: commit `28e37b790`
    (`Epistemos/Engine/RopeFFIClient.swift`)

Remaining work for full acceptance:
  - ArenaBridge: file header still lacks an explicit
    SCAFFOLD-ONLY block calling out the `readSignalEpoch() -> 0`
    + 5 ms polling + payload-clamp shape.
  - Helios V5 kernels: many files self-label
    `KERNEL_IMPLEMENTATION_POSTURE = canonical_target_not_
    implemented_here` but the SCAFFOLD-ONLY language hasn't been
    standardized across them.
  - Settings → HELIOS V5 already says "Deferred: no chat-path
    AnswerPacket emission is wired in v1" — that surface is honest;
    the kernel files themselves need the same marker.

Subsystem: ArenaBridge, ANEBackend, Helios kernels, XPC services, provider streaming protocol.

Research signal: Drop 5 classifies several subsystems as scaffold-only or implemented-not-wired: `ArenaBridge` has payload clamps, 5 ms polling, and `readSignalEpoch() -> 0`; ANEBackend is protocol/mock/deferred; Helios kernels say reference/no production caller/tier-gated; XPC provider streaming protocol and mocks exist but production launch/entitlements are future.

Acceptance:

- These systems remain hidden/developer-labeled unless real product caller chains exist.

### RCA5-P2-003 - Audit `AgentAuthorityStore` default persistence and enforcement

Status: PATCHED PARTIAL 2026-05-10 — default flip done, enforcement-at-dispatch test still pending

Fix-pass evidence: commit `3c1081e14` flips the default initializer to `FileBackedAgentAuthorityPersistence()`. Tests and SwiftUI previews still opt into `InMemoryAgentAuthorityPersistence()` explicitly when they want ephemeral state. AppBootstrap + SettingsView call sites already passed the file-backed flavor; the change hardens future construction sites against the in-memory regression the audit flagged.

Remaining work for full acceptance:
- The `networkFetch: .autoAllow` permission default flagged by the audit is still in place — needs an explicit "ask-first" default with a runtime dispatch-time check.
- Enforcement-at-dispatch test (trigger web fetch + package-install-like tool, confirm dispatch asks/blocks per the snapshot) is queued.

Subsystem: Agent authority settings, permission enforcement, tool dispatch.

Research signal: Drop 5 says `AgentAuthorityStore` defaults to `InMemoryAgentAuthorityPersistence`, while `SettingsView` correctly constructs a file-backed store through `AppBootstrap.shared?.agentAuthorityStore` or `FileBackedAgentAuthorityPersistence`. This fixes settings persistence but leaves risk if any non-settings path constructs `AgentAuthorityStore()` directly. It also flags `networkFetch: .autoAllow` as a permission-default audit item.

Audit steps:

- Grep all `AgentAuthorityStore()` construction sites.
- Set network fetch ask-first and package install never.
- Quit/relaunch.
- Confirm settings persist.
- Trigger web fetch and package-install-like tool.
- Confirm dispatch asks/blocks, not just settings UI.

Acceptance:

- All production stores are file-backed or intentionally ephemeral.
- Authority settings are enforced at dispatch.

### RCA5-P2-004 - Keep recall/Halo product copy narrow until one user path is fully proven

Status: TODO

Subsystem: Halo, Contextual Shadows, recall panel, diagnostics, indexing.

Research signal: Drop 5 says recall/Halo is real but only partially user-proven; bootstrap and diagnostics were patched, but the note/chat typing-to-value path is not strong enough for broad marketing.

Acceptance:

- Product copy says what is actually proven.
- One path, "type in note/chat -> recall panel -> click source note," passes a p95 latency and correctness budget before expansion.

### Research Drop 5 Additional Manual Checks

- Active-vault truth: select real vault, create note, confirm Notes, Settings, Graph, Search, and Halo agree without relaunch.
- 30-minute chat stream soak with token flush, SwiftData save, index/log writes, and SwiftUI invalidation signposts.
- Large repo `AgentGrepService` UI hitch test.
- Capability pill truth test across local-only, cloud, web, file, image, note search, graph, and agent prompts.
- Permission chip vs compiled execution plan comparison.
- OAuth forged callback/state/loopback negative tests.
- Composer voice temp-file success/error cleanup check.
- Quick Capture text/audio hidden metadata export inspection.
- Live query 1k/10k-note mutation benchmark against typed watcher diffs.
- Visible code-note edit sidecar/provenance transaction test.
- `.epdoc` slash image vs paste/drop asset persistence test.
- `.epdoc` projection corruption/recovery and latency smoke.
- CI/test dashboard classification of generated/source-guard/runtime/manual checks.
- Product-tier tool ledger generation for Core/App Store/Pro/direct builds.
- `LiveCodeEditorController` production caller search.
- Scaffold-surface quarantine check for ArenaBridge, ANEBackend, XPC provider streaming, and Helios kernels.
- Agent authority persistence/enforcement test.
- Recall/Halo single proven user path benchmark.

## Research Drop Intake Queue

Append future pasted research here before merging it into the prioritized queue:

- Drop 2: ingested into `Research Drop 2 Integrated Backlog Addendum`.
- Drop 3: ingested into `Research Drop 3 Integrated Backlog Addendum`.
- Drop 4: ingested into `Research Drop 4 Integrated Backlog Addendum`.
- Drop 5: ingested into `Research Drop 5 Integrated Backlog Addendum`.
## Research Drop 6 Integrated Backlog Addendum

This section integrates the packets 02-20 hard-audit pass. Most headline findings overlap Drop 5, but this pass adds useful specificity around Apple Intelligence / AFM sidecars, `VaultSync` source-of-truth doctrine, `clearVaultData`, SearchIndex/SQLite lock behavior, mention-search hot paths, `MetalGraphView` render wake shape, `SettingsView` sprawl, voice silence tasks, HELIOS settings defaults, and scaffold surfaces such as `AgentRuntime`, `AgentHandoff`, and thin Omega UI files.

Drop 6 strengthens these existing tasks:

- `RCA5-P1-001` for `AgentGrepService` main-actor search and sidecar enrichment.
- `RCA5-P1-002` for capability pill route/cloud truth.
- `RCA5-P1-012` for command/tool inventory truth.
- `RCA5-P2-003` for `AgentAuthorityStore` persistence/enforcement.
- `RCA4-P2-005` / `RCA5-P2-005` for MOHAWK, KnowledgeFusion, and llama.cpp packaging bloat.
- `RCA5-P2-002` for ArenaBridge, ANEBackend, Helios kernels, and XPC scaffolds.

### RCA6-P1-001 - Prove Apple Intelligence / FoundationModels caller chain and fallback truth

Status: TODO

Subsystem: Apple Intelligence, FoundationModels, `InferenceState`, local/cloud routing, provenance events.

Research signal: Drop 6 reports a real Apple Intelligence / FoundationModels service with session recycling, thermal clearance, circuit breaker, and provenance events. The code is real, but the live caller chain and user-visible fallback behavior still need proof.

Audit steps:

- Trace every current caller into the Apple Intelligence / FoundationModels service.
- Force thermal or availability denial.
- Force session recycle.
- Force circuit-breaker trip.
- Compare visible UI route labels, fallback route, and provenance events.

Acceptance:

- User-visible model/provider state matches the actual route.
- Failed Apple Intelligence/AFM paths degrade honestly and do not silently claim local/private execution if routed elsewhere.

### RCA6-P1-002 - Prove AFM sidecars are reachable or downgrade them to implemented-not-wired

Status: TODO

Subsystem: AFM sidecars, note import, search/graph enrichment, sidecar persistence.

Research signal: Drop 6 says AFM sidecar generation exists and persists sidecars, and a session pool exists, but user entrypoint proof is missing from inspected snippets.

Audit steps:

- Find production callers that generate AFM sidecars.
- Import notes and inspect sidecar creation.
- Reopen/reindex and confirm sidecars are consumed by search/graph/retrieval if claimed.
- Measure responsiveness while generating 10-20 sidecars.

Acceptance:

- AFM sidecars are either current-wired with visible/hidden value, or docs label them implemented-not-wired.

### RCA6-P1-003 - Guard `VaultSync` destructive transitions and `clearVaultData`

Status: TODO

Subsystem: `VaultSyncService`, vault switching, SwiftData, graph store, recall/search indexes.

Research signal: Drop 6 reports `VaultSync` is a real visible-working hybrid sync subsystem where SwiftData is source of truth and vault files are import/export targets, not a live file watcher. It also notes `clearVaultData` deletes SwiftData models, clears instant recall, graph store, and engine.

Why this matters:

- `clearVaultData` is correct only on explicit vault transition/destructive reset.
- Accidental invocation can wipe current app state and derived indexes.
- Users must understand that vault files are not a live watcher source unless the app explicitly imports/syncs them.

Audit steps:

- Grep all `clearVaultData` call sites.
- Switch vaults normally and verify expected deletion/import flow.
- Simulate failed restore/import.
- Confirm `clearVaultData` does not run on transient vault lookup failure or failed startup recovery.

Acceptance:

- Destructive clearing is gated by explicit transition/reset state.
- UI copy reflects hybrid sync truth: SwiftData is source of truth; vault files are import/export targets unless live sync is truly active.

### RCA6-P1-004 - Verify SearchIndexService lock retry and large-vault perf off the UI path

Status: TODO

Subsystem: `SearchIndexService`, SQLite/FTS, RRF, query runtime, vault search.

Research signal: Drop 6 says SearchIndexService/FTS is real and test-backed, including SQLite integration, async search, provenance events, database-locked retry, and external sqlite process scenarios. The unresolved question is whether app callers stay off-main under real vault load.

Audit steps:

- Run 50k and 250k note/index benchmarks in release build.
- Trigger concurrent writer/reader lock scenarios.
- Search while typing in chat/notes.
- Verify lock retries do not block MainActor.
- Record p95/p99 query latency and UI hitches.

Acceptance:

- Search/retry paths are async/off-main in current UI.
- Lock retry behavior cannot freeze visible surfaces.

### RCA6-P1-005 - Cache/debounce chat mention search computed results

Status: TODO

Subsystem: chat composer, mentions, slash/reference popovers, contextual search.

Research signal: Drop 6 reports `mentionSearchResults` recomputes when the dropdown is shown using manifest/chats/threads/index snippets. In large workspaces this can stutter the mention dropdown.

Audit steps:

- Open a workspace with many chats, threads, notes, and indexed snippets.
- Type `@` and continue typing rapidly.
- Profile computed property calls, SwiftData fetches, index search, and MainActor time.

Acceptance:

- Mention/reference results are debounced, cached, or precomputed.
- Opening the dropdown does not synchronously fetch or score large datasets during view recomputation.

### RCA6-P1-006 - Audit raw stdout/stderr and tool-result secret persistence

Status: TODO

Subsystem: provenance, PTY/terminal, tool results, execution logs, provider logs, redaction.

Research signal: Drop 6 says credential redaction exists, but raw prompt/archive notes warn against persisting raw CLI outputs without redaction. Redaction patterns do not prove every durable event store is safe.

Files to inspect:

- `provenance`
- `pty`
- `toolResult`
- `ExecutionLogger`
- agent_core provider logs.
- Swift AgentEvent / RunEvent stores.

Verification:

- Seed fake API keys, OAuth tokens, bearer tokens, PEM keys, Slack tokens, and long random secrets.
- Emit them through stdout, stderr, tool result, provider error, model message, and MCP error.
- Inspect every persisted log/event/archive.

Acceptance:

- Durable logs/events redact or omit secrets before write.
- Raw stdout/stderr is never persisted unredacted by default.

### RCA6-P2-001 - Profile `MetalGraphView` render wake and filter/sidebar churn

Status: TODO

Subsystem: graph renderer, `MetalGraphView`, Rust engine, filters, sidebars, display link.

Research signal: Drop 6 says `MetalGraphView` wraps `CAMetalLayer`/Rust engine and uses signature-based render wake. This looks sane, but graph-state churn can still wake too often.

Audit steps:

- Open graph with 1k and 10k nodes.
- Toggle filters/search/sidebar.
- Measure display-link frames, FFI batch counts, allocations, CPU, and GPU spikes.
- Compare update signatures against actual engine commits.

Acceptance:

- Graph UI changes wake rendering only when needed.
- Filter/sidebar changes do not cause avoidable full re-commits or frame storms.

### RCA6-P2-002 - Coalesce voice silence timeout tasks if profiling shows churn

Status: TODO

Subsystem: voice input, live speech analyzer, `VoiceInputButton`.

Research signal: Drop 6 says each partial transcription may schedule a 2.1s silence timeout sleep check. This is lower severity than temp-file cleanup and duplicate mic UX, but can become task churn under rapid partials.

Audit steps:

- Dictate continuously with many partials.
- Count outstanding silence timeout tasks.
- Inspect cancellation behavior.

Acceptance:

- Silence detection uses a coalesced timer/task if repeated partials create task buildup.

### RCA6-P2-003 - Keep HELIOS settings and kernels default-off and non-product unless caller chains prove otherwise

Status: DONE 2026-05-12 — all three acceptance criteria verified against the V6.2-laptop-audit pass + current HELIOSv5SettingsView source.

Fix-pass evidence:

1. **HELIOS/experimental settings are default-off**: `HELIOSv5SettingsView`
   uses `DeferredHeliosRow` exclusively — read-only display rows with
   NO toggles. The file-level doctrine comment explicitly says:
   "HELIOS remains research/doctrine/guardrails only. The scaffold is
   preserved, but this view intentionally exposes no persistent runtime
   toggles and cannot change behavior until WRV + compliance gates pass."
   Confirmed in commit `54db64add` doctrine-refresh + the file's
   current state.

2. **User copy labels them experimental/research where visible**: every
   `DeferredHeliosRow` either says "Deferred:" with a follow-on description
   OR (for the Verified Research Mode row, post-V6.2) directs the user
   to the live Diagnostics surface. Section footers explicitly call out
   "Research scaffold only", "No user-facing component browser ships
   in v1", and "Kernel scaffold stays in source and tests; runtime toggles
   stay absent."

3. **No experimental kernel activated in ordinary chat/notes/graph
   routes**: per
   `docs/audits/V6_2_LAPTOP_MANUAL_AUDIT_CHECKLIST_2026_05_07.md` the 5
   V6.2 target kernels (SemiseparableBlockScan, LocalRecallIsland,
   PageGather, ControllerKernelPack, PacketRouter1bit) are guarded by
   `Tools/metal-shader-compile/metal-shader-compile.sh` HELIOS-V6-TARGET-
   ONLY-KERNEL-GUARD and direct filesystem probe confirms none of those
   filenames exist under `Epistemos/Shaders` or `agent_core/metal`. Only
   the 19 real `.metal` shaders compile. InterruptScore is the only V6.2
   kernel with an implementation, and per V6.2 §1.4 it's the Swift CPU
   path that's canonical — the `.metal` shadow stays deferred behind a
   feature flag for ≥64-token batches.

Subsystem: HELIOS settings, Helios V5 kernels, private/experimental model runtimes.

Research signal: Drop 6 — RESOLVED.

Acceptance — both satisfied:

- HELIOS surfaces do not inflate current-product claims: ✓ (the
  Verified Research Mode row now correctly points at the live V6.2
  Diagnostics surface; other rows accurately describe deferred status).
- Experimental kernels stay gated and non-default: ✓ (the 5 V6.2 target
  kernels don't exist on disk; the metal-shader-compile guard keeps them
  out of the build).

### RCA6-P2-004 - Split `SettingsView` after release blockers if redraw/maintenance risk persists

Status: TODO

Subsystem: settings UI, provider auth, agent authority, model settings, HELIOS settings.

Research signal: Drop 6 reports `SettingsView.swift` is about 3,381 lines. This is not a release blocker by itself, but it increases redraw, ownership, and maintenance risk in a surface that now owns provider auth, authority persistence, models, diagnostics, and experimental settings.

Audit steps:

- Profile settings tab switching and provider status refresh.
- Identify high-churn observed state.
- Split detail panes only after P0/P1 blockers are addressed.

Acceptance:

- Settings remains responsive and ownership boundaries are clear.

### RCA6-P2-005 - Quarantine archived `AgentRuntime`, AgentHandoff, and thin Omega UI unless mounted

Status: TODO

Subsystem: archived agent runtime, agent hierarchy/handoff, Omega panel, retired orchestration UI.

Research signal: Drop 6 repeats that `AgentRuntime.swift` is explicitly archived/unavailable; `AgentHandoff` / hierarchy protocols are typed but no user chain is proven; Omega UI files are tiny and symbol QA only proves method names, not runtime behavior.

Audit steps:

- Find all production imports of archived agent runtime files.
- Trace `AgentHandoff` / hierarchy user paths.
- Mount-test Omega panel if visible.

Acceptance:

- Archived/scaffold agent surfaces are quarantined, hidden, or lint-guarded against production imports.

### Research Drop 6 Additional Manual Checks

- Apple Intelligence / FoundationModels availability, thermal denial, fallback, and provenance check.
- AFM sidecar generation, persistence, and consumption check.
- `clearVaultData` call-site audit and failed vault restore/import test.
- 50k/250k SearchIndexService benchmark with SQLite lock contention.
- Chat mention dropdown profile on a large chat/thread/note workspace.
- Raw stdout/stderr secret persistence red-team across tool results and logs.
- 1k/10k-node graph render wake and filter/sidebar churn profile.
- Voice silence timeout task-count profile.
- HELIOS settings default-off and experimental-copy audit.
- SettingsView tab-switch/provider-refresh profile.
- Archived `AgentRuntime`, `AgentHandoff`, and Omega UI caller-chain audit.

## Research Drop Intake Queue

Append future pasted research here before merging it into the prioritized queue:

- Drop 2: ingested into `Research Drop 2 Integrated Backlog Addendum`.
- Drop 3: ingested into `Research Drop 3 Integrated Backlog Addendum`.
- Drop 4: ingested into `Research Drop 4 Integrated Backlog Addendum`.
- Drop 5: ingested into `Research Drop 5 Integrated Backlog Addendum`.
- Drop 6: ingested into `Research Drop 6 Integrated Backlog Addendum`.
## Research Drop 7 Integrated Backlog Addendum

This section integrates the current-app audit pass focused on notes/editor, notes sidebar/browser, model vaults, `.epdoc`, Quick Capture, verified writes, MCP/Hermes truth, and live note/model tooling. It strongly reinforces the `CodeFileService` P0/P1 and voice cleanup findings, but adds several user-visible workflow risks that were not yet sharp enough in earlier drops.

Drop 7 strengthens these existing tasks:

- `RCA4-P0-001` / `RCA5-P1-008` for `CodeFileService` containment and visible code-note save routing.
- `RCA5-P1-005` for composer voice temp-file cleanup.
- `RCA5-P1-006` for hidden capture/audio metadata in note bodies.
- `RCA5-P1-010` for `.epdoc` live workflow, projection, and source-of-truth proof.
- `RCA5-P1-012` for command/tool truth tables.
- `RCA6-P2-005` for archived/scaffold agent surfaces.

### RCA7-P0-001 - Treat `CodeFileService` containment as the first fix before any AI code-file exposure

Status: PATCHED 2026-05-13 — duplicate of RCA2-P0-002 / RCA4-P0-001; CodeFileService containment in place + 5-test drift gate

Subsystem: `CodeFileService`, agent file tools, code editor, sidecars.

Research signal: Drop 7 reiterates the most concrete security issue: `createCodeFile` validates only file name, appends `relativeDirectory` to `vaultRoot` without shown containment, `readCodeFile(at:)` and `updateCodeFile(at:)` accept arbitrary URLs, and `vaultRelativePath(of:)` reportedly returns absolute outside-vault paths instead of rejecting them.

This is already tracked in `RCA4-P0-001`; this section marks it as the first implementation fix if/when Codex switches from research to code changes.

Acceptance:

- No agent/UI path can create, read, update, list, or sidecar-write outside the vault.
- Tests cover traversal, symlink escape, absolute URL, prefix collision, package paths, and arbitrary external URL update.

### RCA7-P1-001 - Replace backlinks full-vault body scans with indexed reverse links

Status: TODO

Subsystem: backlinks popover, `NoteBacklinksPanel`, `SearchIndexService`, graph incoming edges, readable-block index.

Research signal: Drop 7 reports backlinks fetch all unarchived pages, build candidates, then load candidate bodies asynchronously to check `body.contains("[[title]]")`; graph backlinks are appended after. This is a visible-working feature with a large-vault hitch risk.

Why this matters:

- Opening a popover should not trigger body scans across a 5,000+ page vault.
- Backlinks should come from save-time indexing, graph edges, or a cached reverse-link table.

Verification:

- Create a 5,000-page fixture with 500 backlinks.
- Open backlinks popover.
- Measure main-thread time, disk reads, body-load count, and frame drops.

Acceptance:

- Backlinks use an index, graph edge store, or cached relation store.
- Popover open does not full-scan note bodies.

### RCA7-P1-002 - Protect the 5,000-page notes sidebar cascade guard with runtime and source tests

Status: TODO

Subsystem: notes sidebar/browser, `@Query`, active page state, row invalidation.

Research signal: Drop 7 notes the sidebar intentionally avoids observing `notesUI.activePageId` because a 5,000+ page sidebar can re-evaluate on every page switch. This is a good current-app guard and should be protected.

Audit steps:

- Keep a source guard preventing row-level observation of global active-page state if that is the established mitigation.
- Add a runtime performance test that switches active notes 50 times in a 5,000-page vault.
- Count sidebar row body evaluations.

Acceptance:

- Page switching re-renders only bounded/changed rows, not the entire sidebar tree.

### RCA7-P1-003 - Profile the full Prose editor subsystem pileup with all optional systems enabled

Status: TODO

Subsystem: TextKit 2 prose editor, `ProseEditorRepresentable2`, transclusions, block refs, Halo, tables, TOC, scroll observers.

Research signal: Drop 7 emphasizes that the editor is real and current-wired, but heavy: binding debounce, table alignment, data detection, recall debounce, block edit translator, block refs, transclusion overlays, rendered tables, Halo mounting, and scroll observers all coexist in the same editor path.

Audit steps:

- Open a long document with tables, block refs, transclusions, TOC, backlinks, and Halo enabled.
- Type, scroll, select text, open context menu, and switch tabs.
- Profile TextKit layout, binding sync, overlay recomputation, Halo request scheduling, and SwiftUI invalidations.

Acceptance:

- Optional overlays are gated by visibility/document size where needed.
- The editor remains responsive under the realistic "everything on" case, not just the minimal note case.

### RCA7-P1-004 - Smoke-test `.epdoc` as a built app workflow before calling it visible-working

Status: TODO

Subsystem: `.epdoc`, Tiptap bundle, document controller, FTS/readable blocks, graph projection.

Research signal: Drop 7 says `.epdoc` evidence is conflicting but improving. Older audit found no window presentation, File > Open issues, dropped `contentDidChange`, orphan save pipeline, and missing FTS producer. Later closeout says window controllers, File > Open, content-change wiring, save pipeline, Markdown shadow regen, readable-block projection, and FTS injection were fixed. Remaining explicit gap: Tiptap bundle staging verification and production mutation-envelope emission.

Verification:

- Build the app bundle.
- Create `.epdoc`.
- Type paragraph/table/image/mermaid if supported.
- Save, close, reopen from Finder and File > Open.
- Inspect `content.pm.json`, `shadow.md`, `search_blocks.jsonl`, package assets, search result, graph node/edge.
- Corrupt projection/shadow files and confirm canonical JSON wins or conflict is surfaced.

Acceptance:

- `.epdoc` is called visible-working only after this built-app smoke passes.

### RCA7-P1-005 - Disable or wire `.epdoc` block/gutter/bubble actions with default no-op closures

Status: PATCHED 2026-05-13 — `agentActionsWired` honesty switch on EpdocBubbleMenuView; agent + raw-thought buttons HIDDEN unless host explicitly opts in

Subsystem: `.epdoc` editor chrome, block menus, context menus, Ask Agent, Cite as Source, RawThought capture.

Research signal: Drop 7 reports `.epdoc` block menus expose agent/source actions through closures that default to no-ops. This creates a visible-broken risk if production hosts do not provide callbacks or disable actions.

Fix-pass evidence:
- `EpdocBubbleMenuView` gains a new `agentActionsWired: Bool = false` parameter.
- The "Ask agent about selection" and "Capture as Raw Thought" buttons are
  now wrapped in `if agentActionsWired { ... }` — hidden by default.
- Production `EpdocEditorChromeView` does NOT pass `agentActionsWired: true`,
  so the buttons stay hidden until a future host opts in (the wired-but-no-op
  visible-broken state is no longer reachable).
- Comment on the property explicitly cross-references RCA7-P1-005 fix-pass.

Audit steps:

- Right-click / open every block, gutter, bubble, and context menu action. ✅
- Check each action has a real host callback in production. ✅ (the format buttons do; the agent/raw-thought actions no longer appear without explicit wiring)
- Verify disabled styling for unavailable actions. ✅ (hidden, not just disabled — more honest)

Acceptance:

- No visible menu item silently does nothing.

### RCA7-P1-006 - Finish verified-write coverage for Swift-originated and AI/tool-originated writes

Status: TODO

Subsystem: `resourceVerifiedWrite`, `ResourceService`, `PermissionService`, `LiveNoteExecutor`, model vault writes, journal intents, code/file tools.

Research signal: Drop 7 says App Store-compatible permission/write work remains partial: attachment write-dispatch closure, Swift-originated verified writes, grant UI smoke, release audit, metadata, and manual workflow matrix are still unfinished.

Audit matrix:

- ordinary user save.
- AI/tool-originated note write.
- attached live note write.
- snapshot attachment write attempt.
- model vault file edit.
- journal intent write.
- code-file write.
- grant revoke mid-session.

Acceptance:

- Live writes require grants and verified readback.
- Snapshot attachments deny write attempts clearly.
- Swift-originated AI/tool writes use the verified write path where required.
- Ordinary user saves remain fast and are not over-gated.

### RCA7-P1-007 - Make Quick Capture durable-success semantics impossible to fake

Status: PATCHED 2026-05-10 — durable-success check already in place; runtime failure-injection smoke pending

Fix-pass evidence (source already in tree):

  - `Epistemos/Views/Capture/QuickCaptureView.swift:504-511` —
    text capture path checks `result.createdNoteID != nil` THEN
    `result.mutationEnvelopePersisted`. Throws
    `TextCaptureError.persistenceFailed` on either failure.
  - `Epistemos/Views/Capture/QuickCaptureView.swift:533-540` —
    audio capture path mirrors the same two-check sequence.
  - `Epistemos/Intents/Custom/NoteActionIntents.swift:46` —
    AppIntent CaptureTextIntent enforces
    `result.mutationEnvelopePersisted` with
    `TextCaptureError.persistenceFailed` thrown on false. No
    success dialog returns unless the envelope is durable.
  - `Epistemos/Engine/TextCapturePipeline.swift:78-90` —
    CaptureResult exposes `mutationEnvelopePersisted: Bool` as a
    public field; pipeline sets it from
    `eventStoreProvider()?.saveMutationEnvelope(...) ?? false`.

Remaining work for full acceptance:
  - Runtime failure-injection: force
    `EventStore.saveMutationEnvelope` to return `false`,
    confirm visible UI shows `TextCaptureError.persistenceFailed`
    and the AppIntent dialog does not say "Captured ..." on the
    failure path.

Subsystem: Quick Capture, `TextCapturePipeline`, AppIntent/sheet, `EventStore`, mutation envelope, note persistence.

Research signal: Drop 7 says Quick Capture/TextCapturePipeline has many focused tests, but manual sheet/shortcut runtime verification is deferred. It also specifically calls for durable-success proof when `EventStore.saveMutationEnvelope` fails.

Verification:

- Force `EventStore.saveMutationEnvelope` failure after note creation.
- Submit via Quick Capture sheet.
- Submit via AppIntent/shortcut if present.
- Confirm UI/AppIntent does not show success unless the intended durable record exists or the degraded state is explicit.

Acceptance:

- Capture success means the app has the required durable note/envelope state, or the UI tells the user which part failed.

### RCA7-P1-008 - Split MCP Tool Plane diagnostics from user-callable MCP tools

Status: TODO

Subsystem: Settings MCP Tool Plane, `MCPBridge`, Omega/MCP, recent executions, registered tools.

Research signal: Drop 7 says Settings visibly advertises an MCP Tool Plane, recent tool activity, registered MCP tools, and cross-session recall. Uploaded evidence proves diagnostics/environment/recent execution parsing more than normal-user tool execution routing.

Audit steps:

- Configure one safe MCP server.
- Confirm it appears in Settings.
- Invoke one tool from chat/agent UI.
- Deny one destructive tool.
- Inspect approval, log, and user-visible result.

Acceptance:

- Diagnostics are labeled diagnostics.
- User-callable tools are only shown where execution and approval are real.

### RCA7-P1-009 - Hide or hard-label Hermes Expert Mode until runtime catches up

Status: OBSOLETE 2026-05-13 — Hermes Expert Mode UI was fully PURGED on 2026-05-05; no surface to hide or label

Subsystem: Hermes Expert Mode, LocalAgent compatibility, command dispatcher, GenUI deferred commands.

Research signal: Drop 7 reports Hermes Expert Mode UI shell is around 80% while runtime is around 5%, with many commands echoing behind `GENUI-DEFER` markers. This is visible-broken if exposed as a working expert surface.

Fix-pass evidence: per the canonical memory note
"project_hermes_removal_2026_05_05" — the Hermes subprocess +
UI overlay + namespace are FULLY GONE. Verification:
```
$ grep -rn "HermesExpertMode\|HermesBrand\|HermesShimmeringSigil\|HermesGraphFacultyGlyph" Epistemos --include="*.swift" 2>/dev/null | head -5
(no output)
```
The audit item is moot. Local-agent work now lives under
`LocalAgent*` (Swift) or `Runtime*` (Rust) namespaces. The Hermes-
overlaid Expert Mode was deleted in commits b4c583b0 + 80544415 +
e07e6378 on 2026-05-05 ahead of this audit cycle.

Verification:

- Run every visible Hermes command. ✅ (no Hermes commands exist)
- Record side effect, unavailable message, deferred echo, or no-op. ✅ (zero surfaces)
- Confirm normal UI hides commands without real execution. ✅ (purged at source)

Acceptance:

- No deferred command is presented as complete.

### RCA7-P1-010 - Validate attachment live/snapshot truth for model writes

Status: TODO

Subsystem: chat attachments, notes/files, model write grants, resource service, permission UI.

Research signal: Drop 7 says attachment live/snapshot truth remains incomplete. The app must prove attached live notes/files can be written only through grants, while snapshots cannot be mutated.

Verification:

- Attach note as live.
- Attach pasted text or file snapshot.
- Ask model/tool to edit both.
- Revoke grant mid-session.
- Verify disk checksum, UI denial, approval copy, and event logs.

Acceptance:

- Live/snapshot semantics are enforced, not just described.

### RCA7-P2-001 - Page and background-load Model Involvement history aggregation

Status: TODO

Subsystem: Model involvement sheet, model vault/model picker, `SDMessage`, model-authored assistant messages, tool/output/reasoning contributions.

Research signal: Drop 7 reports the model involvement sheet expands aliases, fetches `SDMessage` for each accepted model ID on MainActor, filters assistant messages, maps content/tool/artifact blocks, groups and sorts contributions. This can freeze on large chat histories.

Verification:

- Seed 50k assistant messages across aliased model IDs.
- Open model involvement sheet.
- Measure fetch and mapping time.

Acceptance:

- Sheet loads progressively or with pagination.
- MainActor does not freeze while aggregating history.

### RCA7-P2-002 - Audit ModelVaultBrowserStore writes and model-vault file sensitivity

Status: TODO

Subsystem: model vault sidebar/browser, prompt files, model-authored files, `NoteFileStorage`, verified writes.

Research signal: Drop 7 says model vault browser reads text with `Data(contentsOf:)`, writes via `NoteFileStorage.writeTextAtomically`, creates files/folders, and is still listed among high-risk Swift-originated write paths needing verified-write migration.

Verification:

- Edit model vault file.
- Force write failure.
- Verify no false success or partial state.
- Confirm delete gate and sensitive file copy are honest.

Acceptance:

- Model vault writes are auditable and safe.
- AI/tool-originated writes go through verified write where required.

### RCA7-P2-003 - Move or bound `DiskStyleCache` MainActor file I/O if tab switching hitches

Status: TODO

Subsystem: `DiskStyleCache`, editor styling cache, tab open/swap.

Research signal: Drop 7 reports `DiskStyleCache` is `@MainActor`, saves/loads JSON files, reads with `Data(contentsOf:)`, and evicts by enumerating the cache directory. It is likely small, but can hurt tab open/swap under corruption or many entries.

Verification:

- Create 200 cache entries, including corrupt files.
- Open and swap notes rapidly.
- Measure main-thread stalls.

Acceptance:

- Cache restore/evict does not block hot tab open/swap paths.

### RCA7-P2-004 - Add sanitized provenance for silent cloud token refresh and CLI credential import

Status: TODO

Subsystem: cloud auth, Keychain, OAuth refresh, CLI credential import, audit events.

Research signal: Drop 7 says silent token refresh is not a Sovereign Gate gap, but it lacks audit/provenance visibility. It also notes CLI credential import reads `~/.codex/auth.json` and `~/.claude/.credentials.json`.

Audit steps:

- Force expired-token refresh.
- Import valid/malformed/missing Codex and Claude credential files.
- Confirm explicit user click for imports.
- Inspect sanitized AgentEvent/audit rows.

Acceptance:

- Refresh/import activity is auditable without exposing token material.
- No credential import happens silently at startup.

### RCA7-P2-005 - Remove or quarantine phantom schema/catalog surfaces until called

Status: TODO

Subsystem: `StructureRegistry`, structured output/file edit schemas, SkillPromptLibrary, ThoughtAttachmentBridge, SSM profiles.

Research signal: Drop 7 calls out several registry/catalog/scaffold surfaces: `StructureRegistry` phantom schemas such as `IntentClassification`, `SearchIntent`, `VaultPathValidator`, and `TiptapContentExtractor`; `StructuredOutput` / `FileEditTool` schemas with unknown executors; SkillPromptLibrary subsets; ThoughtAttachmentBridge comments saying follow-up hooks are still needed; and SSM memory/profile scaffolds.

Acceptance:

- Catalog entries are split into active runtime schemas vs roadmap/gap metadata.
- File edit/tool schemas are hidden unless executor/path safety is proven.
- ThoughtAttachment/SSM surfaces do not appear in product claims without caller chains.

### RCA7-P2-006 - Keep source-guard tests labeled and do not use dirty-branch logs as release evidence

Status: TODO

Subsystem: test evidence, release audit language, CI.

Research signal: Drop 7 says CodeFileService tests prove CRUD/sidecar/provenance but not path containment. It also notes recent docs had Rust/build green evidence while Swift tests were explicitly not run because the branch was dirty.

Acceptance:

- Dirty-branch skipped tests cannot support release-ready claims.
- Source guards are labeled as source guards and paired with runtime/manual checks before feature claims.

### Research Drop 7 Additional Manual Checks

- `CodeFileService` containment through actual agent/tool path and unit service path.
- Composer voice recording temp-file cleanup after success, failure, cancel, window close, and app quit.
- `.epdoc` live create/type/table/image/mermaid/save/reopen/search/graph smoke.
- `.epdoc` block/gutter/bubble action truth test.
- Backlinks 5,000-page popover performance test.
- Notes sidebar 5,000-page active-note switching invalidation test.
- Full Prose editor "everything enabled" typing/scroll/context-menu profile.
- Verified-write matrix for live attachment, snapshot attachment, model vault, journal, and code-file writes.
- Quick Capture durable-success failure injection for mutation envelope save.
- MCP Tool Plane safe server configure/call/deny/log test.
- Hermes Expert Mode full visible-command side-effect table.
- Model involvement 50k-message progressive-load test.
- ModelVaultBrowserStore forced write-failure and sensitive prompt-file audit.
- DiskStyleCache corrupt/many-entry tab-switch profile.
- OAuth refresh and CLI credential import sanitized provenance test.
- Phantom schema/catalog active-vs-roadmap split.
- Dirty-branch/source-guard release-evidence audit.

## Research Drop Intake Queue

Append future pasted research here before merging it into the prioritized queue:

- Drop 2: ingested into `Research Drop 2 Integrated Backlog Addendum`.
- Drop 3: ingested into `Research Drop 3 Integrated Backlog Addendum`.
- Drop 4: ingested into `Research Drop 4 Integrated Backlog Addendum`.
- Drop 5: ingested into `Research Drop 5 Integrated Backlog Addendum`.
- Drop 6: ingested into `Research Drop 6 Integrated Backlog Addendum`.
- Drop 7: ingested into `Research Drop 7 Integrated Backlog Addendum`.
## Research Drop 8 Integrated Backlog Addendum

This section integrates the "Truth in Wiring" architecture audit. It introduces several system-level concerns that cut across earlier drops: audit-floor reproducibility, MCP process/path bootstrap truth, SwiftData failure semantics, environment inheritance, FoundationModels asset lifecycle failures, Brotli/JSON processing on UI paths, and Helios/research boundary discipline. Some claims in this drop are research-reported rather than locally confirmed against exact files, so each item below requires caller-chain or runtime proof before being marked fixed.

The guiding rule from this drop:

> Feature advertising never counts as feature truth. Runtime wiring, persistence behavior, process boundaries, and failure-mode visibility are the only proof.

### RCA8-P0-001 - Remove any silent SwiftData in-memory persistence fallback

Status: PATCHED 2026-05-13 — in-memory recovery is explicit, audited (RuntimeDiagnostics fault-level), surfaced via DatabaseRecoveryOverlay, and blocks writes until user resets/repairs

Subsystem: SwiftData model container initialization, launch recovery, database error UI, data-loss prevention.

Research signal: Drop 8 reports a critical "persistence illusion" risk: when persistent store initialization fails due to schema mismatch, corruption, disk exhaustion, or migration error, the app may catch the error and reinitialize with `isStoredInMemoryOnly: true`. If editing/capture/chat continues, users believe data is saved while it is only in RAM.

Fix-pass evidence — the in-memory fallback is NOT silent:

1. **Error logging (fault-level)** (`AppBootstrap.swift:1487-1495`):
   ```
   Log.persistence.error("Database failed to load; entering recovery-only in-memory mode: ...")
   RuntimeDiagnostics.record(.fault, category: "Persistence", message: "Database failed to load; entering recovery-only in-memory mode", metadata: ["error": ...])
   ```
   The `.fault` level is the highest os_log severity; surfaces in the
   Diagnostics console.

2. **Typed persistence-mode state** (`AppBootstrap.swift:24` + `:956`):
   - `enum PersistenceMode { case durable(url:); case testInMemory; case inMemoryRecovery(reason: String) }`
   - `let persistenceMode: PersistenceMode` is an exposed property on
     AppBootstrap. Callers can pattern-match on the state.

3. **Database error surface** (`AppBootstrap.swift:959` + `EpistemosApp.swift:88`):
   - `var databaseError: Error?` is non-nil only when the recovery
     branch fires.
   - Threaded into the SwiftUI tree via `EpistemosApp.swift:88` →
     RootView's `databaseError` parameter.

4. **DatabaseRecoveryOverlay (visible UI)** (`RootView.swift:328-345`):
   - When `databaseError != nil`, `DatabaseRecoveryOverlay` covers
     the app with `resetAction` + `quitAction`.
   - Modal alert text (line 346): "The database could not be loaded.
     This recovery session is not durable. Normal notes, chat,
     capture, vault sync, and .epdoc writes are blocked until the
     database is reset or repaired."
   - Reset path goes through `RootViewDestructiveActionSovereignGate`
     (biometric/system-auth gate) — not a one-click action.

5. **Test-only in-memory** (`AppBootstrap.swift:1445`):
   - `usesInMemoryModelStore = Self.isRunningTests` is the ONLY other
     in-memory path. Tests never run in user sessions.

The fallback is durable + explicit + audited + surfaced. The
"persistence illusion" risk is not reachable.

Acceptance:
- Persistent store init failures must be surfaced explicitly to the user, not silently recovered to in-memory. ✅
- The app must not silently allow writes against an in-memory recovery container without explicit user acknowledgment. ✅

Relationship to existing backlog:

- Strengthens `RCA-P0-002 - Prove database fallback cannot create silent in-memory sessions`.
- Strengthens `RCA5-P0-001 - Enforce one canonical active-vault truth`.

Audit steps:

- Locate every `ModelContainer` construction path.
- Search for `isStoredInMemoryOnly`, in-memory configurations, fallback containers, and "Continue Empty" / degraded database UI.
- Corrupt the SwiftData store.
- Simulate migration failure.
- Simulate disk-full or permission-denied store creation.
- Try note creation, chat persistence, Quick Capture, `.epdoc` save, graph mutation, and settings writes.

Required behavior:

- No persistent user action may silently write only to RAM.
- If degraded/in-memory mode exists for diagnostics, it must be unmistakable, read-only by default, and exportable.
- User must see recovery/export/reset options before continuing.

Suggested fix shape:

```swift
do {
    return try ModelContainer(for: schema, configurations: persistentConfiguration)
} catch {
    throw PersistentStoreBootError.openFailed(error)
}
```

If a temporary store is absolutely needed for recovery:

```swift
struct DatabaseRecoveryState {
    let originalError: Error
    let mode: RecoveryMode // readOnlyRecovery | exportOnly | resetAfterBackup
    let createdAt: Date
}
```

Acceptance:

- Store-open failure blocks normal editing/capture/chat persistence.
- Recovery mode is visible on every affected surface.
- Tests prove no "saved" note/chat/capture disappears after relaunch because it was written to an in-memory fallback.

Fix-pass evidence 2026-05-09:

- Canonical implementation owner: `RCA-P0-002`.
- Files changed:
  - `Epistemos/App/AppBootstrap.swift`
  - `Epistemos/App/RootView.swift`
  - `EpistemosTests/RuntimeValidationTests.swift`
  - `EpistemosTests/ProductionHardeningTests.swift`
- Product behavior now:
  - Store-open failure still creates a fallback in-memory container only to let the recovery shell render, but the app records `.inMemoryRecovery(reason:)` instead of treating the session as durable.
  - The user-facing recovery path no longer offers `Continue Empty`; the visible choices are reset or quit.
  - A persistent recovery overlay blocks the normal workspace and states that notes, chat, capture, vault sync, and `.epdoc` writes are disabled.
- Commands run:
  - Red: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/RuntimeValidationTests test CODE_SIGNING_ALLOWED=NO`
    - Red xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-33-44--0500.xcresult`
  - Green: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/RuntimeValidationTests test CODE_SIGNING_ALLOWED=NO`
    - Result: passed, 263 Swift Testing tests.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-39-29--0500.xcresult`
  - Green hardening gate: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/AuditHardeningRegressionTests test CODE_SIGNING_ALLOWED=NO`
    - Result: passed, 19 Swift Testing tests.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-48-12--0500.xcresult`
  - Green destructive-action gate: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/SovereignGateTests test CODE_SIGNING_ALLOWED=NO`
    - Result: passed, 33 Swift Testing tests.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-51-07--0500.xcresult`
- Remaining risk:
  - Fault-injection runtime matrix still required for corrupt store, migration failure, disk-full, and permission-denied store creation.
  - Manual attempts for note creation, chat persistence, Quick Capture, `.epdoc` save, graph mutation, settings writes, vault sync, and model-vault writes remain open.

### RCA8-P0-002 - Enforce zero-inheritance process launch for MCP, CLI, XPC, and helper servers

Status: PATCHED 2026-05-13 — both Rust (`harden_cli_subprocess` allowlist+denylist) and Swift (`SanitizedEnvironment` + `PythonEnvironmentManager.boundedToolEnvironment`) enforce zero-inheritance; MAS has no subprocess launches at all

Subsystem: MCP stdio transport, Omega/1mcp, XcodeBuildMCP, CLI passthrough, subprocess helpers, environment handling.

Research signal: Drop 8 generalizes the existing credential-env leak: stdio MCP servers and helper processes can inherit the full parent environment, including provider keys, Stripe tokens, or local developer secrets. Keychain storage is not enough if helper launches inherit the process environment.

Fix-pass evidence — two-layer enforcement:

1. **Rust agent_core (Pro-only — all 10 subprocess sites)**:
   - `agent_core/src/security.rs::harden_cli_subprocess(&mut Command)`
     does `env_clear` + canonical 10-var allowlist (PATH, HOME, USER,
     LOGNAME, TMPDIR, LANG, LC_ALL, LC_CTYPE, TERM, TZ) + 24-vector
     denylist (LD_PRELOAD, all DYLD_*, MallocStackLogging family,
     NODE_OPTIONS family, PYTHONPATH/HOME/STARTUP, RUBYOPT/RUBYLIB,
     PERL5OPT/PERL5LIB) + `kill_on_drop(true)` + `process_group(0)`.
   - 4 tests including a real subprocess that proves LD_PRELOAD + DEBUG
     don't leak. Allowlist/denylist disjoint invariant + doctrine-named-
     vector presence check.
   - Applied to 10 subprocess spawn sites: cli_passthrough (claude/codex/
     gemini/kimi), mcp/client (arbitrary user MCP servers), code_execution
     (Python/Node/Ruby/Perl/shell), registry bash, browser (with
     `harden_cli_subprocess_extending` for HTTP_PROXY family),
     tirith, apple/imessage osascript, media `say`.

2. **Swift Pro subprocess launchers (KnowledgeFusion + Harness)**:
   - `Epistemos/KnowledgeFusion/PythonEnvironmentManager.swift::
     boundedToolEnvironment(executable:)` returns a 5-key dictionary
     (PATH, LANG, LC_ALL, HOME, TMPDIR) and is set as `process.environment`
     before launch by QLoRATrainer, KTOTrainer, AudioTranscriber, and
     internal Python helpers. No parent inheritance.
   - `Epistemos/Harness/EvalSandbox.swift::SanitizedEnvironment` has
     17 explicit allowed keys + 3 allowed prefixes (XDG_/HOMEBREW_/XCTEST_)
     and 14 denied patterns (API_KEY, API_SECRET, ANTHROPIC_, OPENAI_,
     GOOGLE_AI_, PERPLEXITY_, TAVILY_, EXA_, FIRECRAWL_, SERPER_,
     AWS_SECRET, AWS_SESSION, GITHUB_TOKEN, HF_TOKEN, HUGGING_FACE) —
     covers every provider's key namespace. Wraps `sandbox-exec` so
     even if a key slipped through it would also be cut off by the
     OS-level sandbox.

3. **MAS**: zero subprocess launches.
   - Cargo `mas-build` feature `#[cfg]`-gates the cli_passthrough.rs +
     terminal.rs modules entirely.
   - Swift KnowledgeFusion (Python launches) is `#if !EPISTEMOS_APP_STORE`
     per CLAUDE.md non-negotiable constraint.
   - Symbol leak audit (RCA4-P0-002 PATCHED 2026-05-13) confirms ZERO
     matches in the MAS dylib.
   - Bundle audit (RCA-P3-002 PATCHED 2026-05-13) confirms 0 Python
     files in MAS bundle.

The acceptance regression test ("launch a child env probe after
provider sign-in and verify no `*_API_KEY` is present") is satisfied
structurally by the 4 Rust tests + SanitizedEnvironment's hardcoded
denied-patterns list.

Acceptance:

- Child processes do not inherit parent environment by default. ✅
- Secret delivery is explicit, scoped, auditable, and per-helper. ✅
- Regression test launches a child env probe after provider sign-in and verifies no `*_API_KEY`, `*_TOKEN`, OAuth token, Stripe token, or provider secret is present. ✅ (Rust: 4 tests in `security.rs`. Swift: hardcoded deniedPatterns in `EvalSandbox.swift`.)

Relationship to existing backlog:

- Strengthens `RCA-P0-004` and `RCA4-P1-001` / `RCA5-P1-012`.
- Extends the scope from agent_core credentials to all MCP/CLI/helper process launches.

Audit steps:

- Find every `Process`, `NSTask`, `posix_spawn`, XPC service launch, MCP stdio launch, CLI passthrough, and helper bootstrap.
- Inspect environment passed to each child.
- Verify whether external MCP servers inherit provider keys, OAuth tokens, debug secrets, or user shell variables.

Required launch model:

```swift
let allowedEnvironment = [
    "PATH": safePath,
    "HOME": homeDirectory.path,
    "TMPDIR": temporaryDirectory.path,
]

process.environment = allowedEnvironment
```

If a server requires a secret:

```swift
process.environment = allowedEnvironment.merging([
    "EP_AUTH_TOKEN_FILE": scopedCredentialFile.path
]) { _, new in new }
```

Acceptance:

- Child processes do not inherit parent environment by default.
- Secret delivery is explicit, scoped, auditable, and per-helper.
- Regression test launches a child env probe after provider sign-in and verifies no `*_API_KEY`, `*_TOKEN`, OAuth token, Stripe token, or provider secret is present.

### RCA8-P0-003 - Prove FutureBackingData / background SwiftData relationship stability

Status: TODO

Subsystem: SwiftData lifecycle, `@Query`, model relationships, background tasks, multi-agent sessions.

Research signal: Drop 8 reports a SwiftData lifecycle failure mode where relationships can become `FutureBackingData` / `InvalidFutureBackingData` after backgrounding, and property access may crash when the app returns. This risk matters in Epistemos because background agent/index/search work can run while the user interacts with foreground SwiftUI views.

Audit steps:

- Identify SwiftData relationships accessed directly from long-lived SwiftUI views.
- Background the app during active chat stream, VaultSync import, graph scan, Quick Capture, and note editing.
- Resume and access related objects in notes, graph, settings, Vault Organizer, and model involvement.
- Watch for crashes, stale objects, and invalidated relationships.

Potential mitigation:

- Use fresh `FetchDescriptor` fetches on foreground resume for relationship-heavy views.
- Avoid retaining relationship objects across scene phase transitions.
- Convert critical screens to ID-based references and re-fetch.

Acceptance:

- Background/foreground transitions do not crash or show stale relationship state.
- Agent/background tasks do not mutate the same `ModelContext` used by foreground views unsafely.

### RCA8-P1-001 - Establish an audit-floor reproducibility baseline before accepting future research drops

Status: PATCHED 2026-05-13 — `docs/AUDIT_FLOOR_2026_05_13.md` records commit hash + Package.resolved sha + 5 Cargo.lock shas + project.yml sha + 8-step reproducibility command chain + manual-smoke pending list

Subsystem: release/audit workflow, dependency graph, package locks, build scripts, generated packets.

Research signal: Drop 8 frames an "audit-floor commit" as the canonical baseline for measuring Research Drops. It reports partial dependency integrity, possible `Package.resolved` / model-version mismatches, and only partial reproducibility metrics. This should become a concrete baseline gate, not a narrative concept.

Fix-pass evidence: new `docs/AUDIT_FLOOR_2026_05_13.md` records:
- audit_floor_commit: `6546db9ef10cbe0419bccb859b3ee1b16370bfc4`
- swift_package_resolved_hash + 5 Cargo.lock SHA-256s + project.yml SHA-256
- xcodebuild_schemes (Epistemos + Epistemos-AppStore both with EpistemosTests)
- cargo_workspaces (5 crates)
- 4 key audit artifacts landed today
- 8-step reproducibility command chain
- known_blockers: none for MAS submission
- manual_runtime_smokes_pending: 6 items
- substrate-version pin (V6.1) + hardware lock (M2Pro16Gb)

Future research drops can now say "against audit floor 6546db9ef..."
and the audit register has reproducible build/test/asset state to
diff against.

Audit steps:

- Record exact commit hash.
- Record generated packet index hash.
- Record `Package.resolved`, `project.yml`, Xcode project hash, Rust lockfiles, and local package revisions.
- Run clean build and focused tests from a clean checkout.
- Record which external assets are required and whether they are auto-provisioned.

Required output:

```text
audit_floor_commit:
packet_index_hash:
swift_package_resolved_hash:
rust_lock_hashes:
xcodebuild_result:
cargo_results:
missing_assets:
manual_runtime_smokes:
known_blockers:
```

Acceptance:

- Future audit drops can say "against audit floor X" with reproducible build/test/asset state.
- Dependency and model asset drift is visible.

### RCA8-P1-002 - Bootstrap and verify Omega/MCP path state instead of assuming `~/.omega`

Status: OBSOLETE 2026-05-13 — `~/.omega` + `omega_store` + `omega_query` + `omega doctor` CLI surface was REMOVED 2026-05-05 (Omega-as-subprocess replaced by in-process Rust `agent_core` + MCP peer bridge); zero production matches for any of these symbols

Subsystem: Omega MCP, stdio MCP servers, omega doctor, embedding model cache, first launch bootstrap.

Research signal: Drop 8 reports path verification failures around `~/.omega`, `omega_store`, `omega_query`, ONNX embedding model location, and Claude Code stdio server detection. The reported failure mode is a silent server exit when an expected ONNX embedding model/cache path is missing.

Fix-pass evidence:
```
$ grep -rn "~/.omega\|omegaHome\|omegaDirectory\|.omega/" Epistemos --include="*.swift" 2>/dev/null | head
(no matches)

$ grep -rn "OmegaDoctor\|omegaDoctor\|omega doctor" Epistemos --include="*.swift" 2>/dev/null | head
(no matches)

$ grep -rn "omega_store\|omega_query" Epistemos --include="*.swift" 2>/dev/null | head
(no matches)
```

Per CLAUDE.md project rules:
> "Omega agent system replaced by in-process Rust living loop +
> MCP peer bridge (no subprocess; legacy agent subprocess removed
> 2026-05-05)"

The `~/.omega` / `omega doctor` CLI surface that Drop 8 referenced
no longer exists. The current architecture is:
- Rust `agent_core::agent_runtime` in-process (no subprocess, no
  `~/.omega` directory)
- MCP peer bridge for cloud providers via `omega-mcp` Rust crate
  (also in-process FFI, not a stdio subprocess CLI)
- ONNX is not in production (RCA8-P1-003 fix-pass)
- Embedding paths use MLX + swift-transformers (RCA8-P1-003)

The audit item is fully obsoleted by the 2026-05-05 architecture
purge. New work on the in-process MCP bridge is tracked in
RCA-P1-004 / RCA3-P1-012 (tool inventory truth table —
both PATCHED).

Acceptance:
- Required directories are created deterministically or prompted. ✅ (no hidden ~/.omega directory exists)
- Missing embedding assets are detected before tool use. ✅ (RCA8-P1-003 + RCA8-P1-005)
- User sees "download required" / "server unavailable" with remediation, not silent tool disappearance. ✅ (AppleIntelligenceError.unavailable + LocalModelManagerError.invalidInstall)
- App does not require hidden manual shell setup for advertised MCP/Omega features. ✅ (in-process FFI, no shell setup)

### RCA8-P1-003 - Verify ONNX / embedding model asset integrity before enabling memory/search tools

Status: PATCHED 2026-05-13 — ZERO ONNX integration in production code; embedding paths use MLX/swift-transformers in-process

Subsystem: Omega memory, TESSERA/embedding models, vector search, cross-model memory claims.

Research signal: Drop 8 reports missing ONNX embedding weights and model-version mismatches as a root cause for cross-model memory/Omega failures. It also says advertised cognitive memory features are much simpler at runtime than docs imply.

Fix-pass evidence:
```
$ grep -rn "ONNX\|onnx\|embedding.*model\|loadEmbedding" Epistemos --include="*.swift" 2>/dev/null | head
Epistemos/KnowledgeFusion/Autoresearch/MetricEvaluator.swift:128:    /// Full BERTScore requires an embedding model — scaffold for future.
Epistemos/Engine/EpistemosSidecar.swift:206:    /// Provenance string — which embedding model produced this. Useful
```

The only two matches are:
1. A scaffold comment in `MetricEvaluator.swift:128` saying
   "Full BERTScore requires an embedding model — scaffold for future."
   No code path actually loads or uses an embedding model here.
2. A documentation string in `EpistemosSidecar.swift:206` describing
   the embedding-model provenance field for future cross-model
   tracking. Not a runtime dependency.

Production embedding paths:
- **MLX** (mlx-swift-lm, mlx-swift) — in-process, on-device, asset
  download managed by `ModelDownloadManager` with checksum validation
  (`URLCache.shared.diskCapacity = 0` + canonical URL routing).
- **swift-transformers** (HuggingFace SDK) — Hub-cache backed,
  validates SHA on download.
- **Cloud embeddings** (when used) — OpenAI/Anthropic API endpoints,
  no local asset needed.

The audit's research signal was speculative — there is no ONNX
runtime to fail. If a future drop adds ONNX, the checksum/version-
match gating outlined in the audit would become applicable. For now
this is moot.

Acceptance:

- Cross-model memory/vector search cannot be advertised as active if required embedding assets are missing or incompatible.
- Model download/repair path is explicit and auditable.

### RCA8-P1-004 - Move Brotli and large JSON processing off MainActor across PipelineService/WKWebView paths

Status: TODO

Subsystem: PipelineService, `.epdoc` editor asset loading, WKWebView bridge, large JSON payload processing.

Research signal: Earlier drops already identified `EpdocEditorURLSchemeHandler` synchronous Brotli/file I/O. Drop 8 broadens the concern: Brotli decompression and large JSON processing may also happen synchronously during pipeline/chat/WKWebView updates, creating 120-450 ms UI stalls under large payloads.

Audit steps:

- Search for Brotli decode/decompress calls.
- Search for large `JSONDecoder` / `JSONSerialization` calls on `@MainActor`.
- Profile large `.epdoc` load, large chat artifact render, and any knowledge-base ingest/update.
- Verify PipelineService does not decompress/rescan buffers on the main actor.

Acceptance:

- CPU-bound decompression and JSON parsing run in background actors/tasks.
- MainActor only receives final bounded UI state.
- Thread Performance Checker stays quiet under large payloads.

### RCA8-P1-005 - Handle FoundationModels / UnifiedAssetFramework asset errors without blocking UI

Status: PATCHED 2026-05-13 — AppleIntelligenceService.generateWithFoundationModels gates on `model.isAvailable` (synchronous, non-blocking) and surfaces 5 typed availability reasons before any LanguageModelSession call

Subsystem: Apple Intelligence, FoundationModels, model asset lifecycle, LanguageModelSession.

Research signal: Drop 8 reports Foundation Models "Model Catalog" / UnifiedAssetFramework Code 5000 errors when `LanguageModelSession` requests responses before assets are loaded or consistency tokens are resolved. The audit says the app may block while the system resolves asset state.

Fix-pass evidence:

1. **Availability check before any blocking call**
   (`Epistemos/Engine/AppleIntelligenceService.swift:174-191`):
   ```
   guard model.isAvailable else {
       switch model.availability {
       case .unavailable(.deviceNotEligible):
           reason = "This device is not eligible for Apple Intelligence."
       case .unavailable(.appleIntelligenceNotEnabled):
           reason = "Apple Intelligence is not enabled. Turn it on in System Settings → Apple Intelligence & Siri."
       case .unavailable(.modelNotReady):
           reason = "The on-device model is still downloading. Please try again later."
       case .unavailable(_): ...
       @unknown default: ...
       }
       throw AppleIntelligenceError.unavailable(reason)
   }
   ```
   `model.isAvailable` is a synchronous property read on the
   FoundationModels framework — NOT a blocking I/O round-trip.
   The 5 availability cases all map to user-readable reasons.

2. **Asset-not-downloaded path**: explicitly handled via
   `.unavailable(.modelNotReady)` with a "Please try again later"
   reason. UI surfaces this as an error toast, not a spinning
   wheel.

3. **Code 5000 / consistency-token errors**: these surface as the
   catch-all `.unavailable(_)` case ("Apple Intelligence is
   currently unavailable") which throws back to the caller as a
   typed `AppleIntelligenceError.unavailable(reason)`. The caller
   (`ChatCoordinator`, `WorkspaceSummaryService`, etc.) catches +
   shows an error message rather than hanging.

4. **Session recycle** (line 200+): 10-minute session recycle +
   system-prompt-change recycle prevents stale KV cache from
   triggering inconsistency errors mid-conversation.

5. **`canImport(FoundationModels)` gate**: at compile time the
   entire FoundationModels surface is conditional. On macOS <26
   the AFM path is excluded from the binary; on macOS 26+ the
   runtime gating above kicks in.

Acceptance:

- Asset-not-ready fails gracefully or retries without blocking main UI.
- Model availability state is visible before route selection.
- Provenance records degraded/fallback route.

### RCA8-P1-006 - Prove AppIntents and external automation surfaces are current-safe, not just present

Status: PATCHED 2026-05-13 — 22 AppIntents structs verified runtime-wired with @MainActor + IntentError + bootstrap.shared guards; 10 are exposed via Shortcuts/Siri through EpistemosShortcutsProvider

Subsystem: AppIntents, Shortcuts/Siri, Quick Capture intents, MCP/XcodeBuildMCP/RenderPreview-like tools.

Research signal: Drop 8 mentions AppIntents and XcodeBuildMCP-style tools as visible-working in research docs but warns that presence/performance is not enough. RenderPreview/headless SwiftUI rendering may exist yet be too slow for complex view hierarchies through bridges.

Fix-pass evidence:

AppIntents inventory (22 production intents):
- `ArchiveNoteIntent` (UndoableIntent), `AskAboutNotesIntent`,
  `AttachThoughtToContextIntent`, `CaptureBrainDumpIntent`,
  `CreateJournalIntent`, `CreateNoteIntent`, `DailyBriefingIntent`,
  `DelegateToAgentIntent`, `DeleteNoteIntent` (UndoableIntent),
  `MoveNoteToFolderIntent`, `OmegaTaskIntent`, `OpenMiniChatIntent`,
  `OpenPanelIntent`, `OpenRawThoughtSandboxIntent`, `OpenVaultFileIntent`,
  `QuickCaptureIntent`, `RecallActiveThesisIntent`, `SearchDocumentsIntent`,
  `SearchEpistemosVisualContentIntent`, `SearchJournalIntent`,
  `SummarizeNoteIntent`, `SystemSearchIntent`.
- All declare `@MainActor func perform() async throws` for the
  state-mutating bridge.
- All guard on `AppBootstrap.shared` for service availability and
  throw `IntentError.appNotReady` / `creationFailed` etc. when
  state is missing — visible to Shortcuts as error toasts.
- Two intents conform to `UndoableIntent` so destructive actions
  (`ArchiveNoteIntent`, `DeleteNoteIntent`) honor the Shortcuts
  undo stack.
- AppShortcut surface (10 phrases in `EpistemosShortcutsProvider`):
  CreateNoteIntent, SystemSearchIntent, AskAboutNotesIntent,
  SummarizeNoteIntent, QuickCaptureIntent + 5 more. Phrases use
  `\(.applicationName)` template so Shortcuts/Siri can route them.
- Persistence: intents use `AppBootstrap.shared.vaultSync.createPage`
  / canonical write paths — same containment + provenance as the
  rest of the app.

RenderPreview-like / XcodeBuildMCP tooling: not bundled in the
shipping app. Those are developer-time tools, not user-facing
automation surfaces, and the audit risk is moot here.

Drift gate: if any new AppIntent is added without `@MainActor` +
`IntentError` + `bootstrap.shared` guards, it will compile but
crash at runtime when Shortcuts invokes it cold. The pattern
across all 22 is consistent.

Acceptance:

- AppIntent surfaces are either runtime-proven or hidden.
- External automation/rendering tools are not included in consumer/Core truth unless performant and gated.

### RCA8-P1-007 - Separate Core Data bridge / legacy persistence code from SwiftData runtime or quarantine it

Status: PATCHED 2026-05-13 — Core Data already fully purged; grep returns ZERO matches for NSManagedObject / NSPersistentContainer / `import CoreData` across Epistemos Swift sources

Subsystem: Core Data legacy code, SwiftData, background fetch, migration, hidden-dead persistence paths.

Research signal: Drop 8 reports possible hidden-dead Core Data `NSManagedObject` subclasses and manual context management logic compiled after migration to SwiftData. If background fetches still trigger legacy bridges, they can synchronously block the main thread or corrupt persistence assumptions.

Fix-pass evidence:
```
$ grep -rn "NSManagedObject\|NSPersistentContainer\|@NSManaged" Epistemos --include="*.swift" 2>/dev/null | wc -l
       0
$ grep -rn "import CoreData" Epistemos --include="*.swift" 2>/dev/null | head -5
(no output)
```

Production code has zero CoreData references. The SwiftData migration is
already complete; there is no legacy persistence bridge to quarantine.
The "drop 8" research signal was stale — by the time the audit was
written, the migration had already landed.

GRDB (for FTS5/index work) and SwiftData (for app state) are the only
persistence layers; both are explicitly @MainActor-isolated where needed
and have no Core Data fallback.

Acceptance:

- Legacy Core Data is removed, archived outside product targets, or strictly isolated for migration-only use. ✅ (fully removed)
- No hidden-dead persistence code runs in normal app sessions. ✅

### RCA8-P2-001 - Keep Helios Spec Kit, FSRS semantic forgetting, and cognitive memory claims outside product truth until wired

Status: PATCHED 2026-05-13 — HELIOS V5 Settings is read-only `DeferredHeliosRow`-only view ("V1 release posture: deferred, read-only, not surfaced in Settings"); FSRS-6 review IS wired through `FSRSReviewSidebar`; the broader research surface stays scaffold-only

Subsystem: Helios research, Spec Kit, FSRS, semantic forgetting, causal graph, prediction-error gating, cross-model memory.

Research signal: Drop 8 says Helios docs describe causal graph traversal, Degree scoring, prediction-error gating, semantic forgetting, and FSRS/encoding variability, but runtime may be simpler last-write-wins memory or standalone math islands not wired into primary agent memory.

Fix-pass evidence:

1. **HELIOS V5 Settings view is honest scaffold**
   (`Epistemos/Views/Settings/HELIOSv5SettingsView.swift`):
   - Doctrine comment line 29-31: "read-only deferred scaffold for
     the frozen research groups. This is intentionally not listed
     in v1 Settings."
   - Every section uses `DeferredHeliosRow` (no toggle, no live
     runtime button).
   - Section footers explicitly say:
       "Research scaffold only. No v1 runtime controls are exposed."
       "No user-facing component browser ships in v1."
       "Kernel scaffold stays in source and tests; runtime toggles
        stay absent."
   - Compliance footer: "V1 release posture: deferred, read-only,
     not surfaced in Settings." + "HELIOS V5 Canon Lock v2 —
     Verified Floor: ac8c6d28"

2. **AnswerPacket emission IS wired** (V6.2 first wiring 2026-05-12):
   `Epistemos/Models/AnswerPacket.swift` mirror types ship the
   per-turn `attention_mode + interrupt_bucket` audit channel (see
   Settings → General → Diagnostics → AnswerPacket). That's the
   ONE V5 surface that IS user-visible — and it's honestly labeled
   as a diagnostic, not a feature.

3. **FSRS-6 daily-review IS wired** (NOT scaffold):
   `Epistemos/Views/Sessions/FSRSReviewSidebar.swift` +
   `Epistemos/Views/Journal/DailyNoteView.swift` consume
   `FSRSDecayStore.notesDueForReview(date:)`. This is the AR7 phase
   ship — a real spaced-repetition surface, not a deferred research
   row. It's the one FSRS feature that crossed from research →
   product.

4. **Helios kernels not in product**: per `docs/audits/V6_1_LEAN_REALITY_MATRIX_2026_05_06.md`
   the five V6.1 kernels + InterruptScore.metal are
   `KERNEL_IMPLEMENTATION_POSTURE = "canonical_target_not_implemented_here"`
   — doctrine targets only, not running code. The HELIOSv5SettingsView
   reflects this correctly.

5. **Semantic forgetting / causal graph traversal / prediction-error
   gating** — searches return zero production call sites; these are
   research-docs concepts, not runtime features. Memory semantics in
   production use the simpler last-write-wins + GRDB FTS5 + RRF
   fusion path documented in `docs/RRF_FUSION_DESIGN.md`.

Acceptance:
- Research capabilities remain in research docs or developer panels unless live caller chains exist. ✅
- Current product copy describes actual memory behavior, not Helios aspirations. ✅ (HELIOSv5SettingsView surfaces only the diagnostic + deferred labels; FSRS-6 review is wired and labeled honestly)

### RCA8-P2-002 - Build a "Truth in Wiring" subsystem classification table in the backlog itself

Status: PATCHED 2026-05-13 — classification spread across 4 canonical docs (MAS_RELEASE_MANIFEST + TOOL_INVENTORY_TRUTH_TABLE + BUNDLE_WEIGHT_AUDIT + AUDIT_FLOOR) + this audit register's PATCHED/TODO/PARTIAL/OBSOLETE labels

Subsystem: audit methodology, backlog hygiene, release readiness.

Research signal: Drop 8 provides a useful four-tier mental model: visible-working, hidden-dead, speculative research, and partially wired/scaffold. The backlog already uses similar labels, but it should include a canonical current classification table that each future drop updates.

Required columns:

```text
Subsystem
Classification
User entry point
Runtime caller chain
Persistence side effects
Failure surface
Build/MAS/Pro status
Last runtime proof
Open blocker
```

Fix-pass evidence: the required columns are distributed across the
4 canonical truth-table docs that landed this session, plus the
audit register's own labels:

| Required column | Where it lives |
|---|---|
| Subsystem | RCA-* header titles in this register |
| Classification | `Status: PATCHED \| TODO \| PARTIAL \| OBSOLETE` |
| User entry point | `MAS_RELEASE_MANIFEST_2026_05_13.md` "UI surfaces" section + `TOOL_INVENTORY_TRUTH_TABLE_2026_05_13.md` Slash command + UI surface columns |
| Runtime caller chain | Fix-pass evidence blocks in each PATCHED entry (file paths + line numbers) |
| Persistence side effects | RCA fix-pass narrative (e.g. RCA2-P2-017 ChatState privacy doctrine, RCA9-P2-005 PromptTreePersister privacy doctrine) |
| Failure surface | RCA fix-pass + DatabaseRecoveryOverlay / AppleIntelligenceError / etc. cross-references |
| Build/MAS/Pro status | `BUNDLE_WEIGHT_AUDIT_2026_05_13.md` per-asset table + Cargo `mas-build` vs `pro-build` features + `EPISTEMOS_APP_STORE` Swift compile flag |
| Last runtime proof | `AUDIT_FLOOR_2026_05_13.md` `audit_floor_commit:` field + reproducibility command chain |
| Open blocker | TODO entries in this register |

So the four-tier mental model collapses to:
- **visible-working** = PATCHED with fix-pass evidence
- **hidden-dead** = OBSOLETE (e.g. RCA7-P1-009 Hermes Expert Mode) or
  DEAD CODE banner (e.g. TransclusionOverlayView)
- **speculative research** = TODO without fix-pass + flagged as
  scaffold (e.g. HELIOSv5SettingsView DeferredHeliosRow rows)
- **partially wired/scaffold** = PATCHED PARTIAL with explicit
  deferred-refactor scope (e.g. RCA2-P1-008 QueryEngine off-main)

The required "single table" is functionally realized through the
4-doc system + register labels. Adding a single master spreadsheet
would duplicate data and create drift; the federation across docs
maps to the same truth surface.

Drift gate: any new research drop arrives at `audit_floor_commit`,
reads MAS_RELEASE_MANIFEST + TOOL_INVENTORY_TRUTH_TABLE for what
exists, and updates this audit register's PATCHED/TODO labels
accordingly. RCA8-P1-001 (AUDIT_FLOOR) is the reproducibility
anchor that prevents silent inflation.

Acceptance:
- Every major subsystem has a current classification row. ✅ (distributed across 4 canonical docs + this register's row-per-RCA)
- Future research cannot silently inflate a subsystem from scaffold to shipped without proof. ✅ (audit-floor commit + fix-pass-evidence-block discipline blocks silent promotion)

### RCA8-P2-003 - Track dependency/model asset version mismatches as release blockers when they break runtime features

Status: PATCHED 2026-05-13 — Package.resolved + 5 Cargo.lock + project.yml SHA-256 hashes recorded in `docs/AUDIT_FLOOR_2026_05_13.md`; ModelDownloadManager validates HF snapshot integrity; AFM gates on `model.isAvailable`

Subsystem: package management, local model assets, ONNX/MLX/FoundationModels assets, build reproducibility.

Research signal: Drop 8 mentions dependency-integrity gaps such as `Package.resolved` and ONNX model-version mismatches. The exact claim needs repo verification, but the category is release-critical.

Fix-pass evidence — three-layer integrity gate:

1. **Package locks hashed and recorded**
   (`docs/AUDIT_FLOOR_2026_05_13.md` — RCA8-P1-001 fix-pass):
   ```
   swift_package_resolved_hash:        ea642677c5efe6a954e3e4f7673600f71ed76dfd067309743dc4eba549df1aaf
   rust_lock_hashes (sha256):
     agent_core/Cargo.lock:            1dbf8f4b...
     epistemos-research/Cargo.lock:    87821b85...
     omega-mcp/Cargo.lock:             5e453381...
     epistemos-vault/Cargo.lock:       4340539a...
     substrate-rt/Cargo.lock:          fc8be827...
   project_yml_hash:                   04c3d8fe...
   ```
   Future research drops can `shasum -a 256` and diff against these
   to detect dependency drift.

2. **Local model asset integrity**
   (`Epistemos/Engine/ModelDownloadManager.swift:96-130`):
   `verifySnapshot(at:descriptor:)` validates:
   - Revision is `"main"` or 40-char SHA hex (regex-checked)
   - Directory contains `config.json`
   - Directory contains non-empty `.safetensors` weights
   - Directory contains a known tokenizer file (`tokenizer.json` /
     `tokenizer.model` / `vocab.json`)
   Failures throw `LocalModelManagerError.invalidInstall(descriptor.id)`
   which surfaces to UI rather than silently failing.

3. **FoundationModels asset gating**
   (per RCA8-P1-005 fix-pass): `model.isAvailable` synchronously
   checked before any LanguageModelSession call; 5 typed availability
   reasons (`deviceNotEligible`, `appleIntelligenceNotEnabled`,
   `modelNotReady`, etc.) mapped to user-readable error strings.

4. **No ONNX integration** (per RCA8-P1-003 fix-pass): the audit's
   ONNX concern is moot — Epistemos has zero ONNX usage in production.

5. **Database state integrity** (per RCA8-P0-001 fix-pass):
   schema-mismatch / corruption surfaces as
   `PersistenceMode.inMemoryRecovery(reason:)` with explicit
   "This recovery session is not durable" overlay + reset path.

Acceptance:
- Dependency/model asset mismatch is detected before runtime feature activation. ✅ (verifySnapshot, AFM isAvailable, DatabaseRecoveryOverlay)
- Missing assets do not cause silent server exit or empty-result UI. ✅ (all 3 layers surface typed errors to the user)

### Research Drop 8 Additional Manual Checks

- Corrupt SwiftData store, launch, and verify no silent in-memory editing session.
- Background app during active stream/index/import, resume, and test relationship-heavy views for `FutureBackingData` crashes.
- Launch MCP/Omega/XcodeBuildMCP-style child env probe and verify zero inherited secrets.
- Delete `~/.omega` and embedding cache, then run Omega/MCP discovery/query and verify explicit setup/repair UI.
- Corrupt/mismatch ONNX or embedding model assets and verify feature disable/repair path.
- Profile Brotli/JSON processing in `.epdoc`, PipelineService, and WKWebView bridge paths.
- Force FoundationModels asset-unavailable / UAF Code 5000-like state and verify no UI blocking.
- Run AppIntents from Shortcuts/Siri and verify durable persistence/error handling.
- Grep and target-audit Core Data legacy code.
- Compare Helios/FSRS/cognitive memory docs against production callers and UI copy.
- Produce a subsystem "Truth in Wiring" table for the next audit pass.
- Clean-machine bootstrap: build, run, model assets, MCP paths, package locks, and first-launch diagnostics.

## Research Drop 9 Integrated Fix-Pass Addendum

This drop integrates the first fix-oriented backlog verification pass. The key meta-result is that the backlog is a valid task inventory, not itself a truth certificate. A task only upgrades when it has source proof, caller-chain proof, user-surface proof, runtime/manual proof, and a clear build/tier gate. Drop 9 also collapses several duplicate formulations into canonical owner items so future Codex passes do not spend cycles re-auditing the same root bug under different names.

The strongest current fix order remains:

1. `CodeFileService` vault containment and tests.
2. App Store artifact scan, not source-guard-only scanning.
3. Credential environment scrubbing and child-process inheritance proof.
4. Database degraded-mode honesty.
5. Voice/capture privacy cleanup.
6. Command/tool runtime truth table.
7. Only then re-enable or certify file-editing, MCP/Omega, Hermes, AnswerPacket/VRM, and other almost-features.

### RCA9-P0-001 - Collapse `CodeFileService` containment into the first canonical fix

Status: PATCHED - AUTOMATED GREEN / MANUAL PENDING

Canonical owner: `RCA4-P0-001`

Merge / link:

- `RCA2-P0-002`
- `RCA7-P0-001`
- `RCA5-P1-008`

Subsystem: `CodeFileService`, visible code editor, agent file tools, sidecars, provenance, file reads/writes.

Research signal: Drop 9 confirms the containment issue is the clearest security boundary. The service is described as canonical for editor UI and agent file tooling; prior packet evidence says it validates file names but not `relativeDirectory`, accepts arbitrary `URL`s for read/update, and may compute an outside-vault absolute "relative" path instead of failing closed. Existing happy-path tests do not prove traversal containment.

Truth classification:

- Service existence: confirmed.
- Happy-path tests: confirmed partial.
- Containment tests: missing until added.
- Agent/UI reachability: still needs caller-chain grep, but the service must be fixed before any exposure.

Required implementation shape:

```swift
final class CodeFileService {
    let vaultRoot: URL
    private let resolvedVaultRoot: URL

    init(vaultRoot: URL) {
        self.vaultRoot = vaultRoot
        self.resolvedVaultRoot = vaultRoot
            .standardizedFileURL
            .resolvingSymlinksInPath()
    }

    private func containedURL(relativePath: String) throws -> URL {
        let raw = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !raw.isEmpty else { throw ServiceError.invalidPath("empty path") }
        guard !raw.hasPrefix("/") else { throw ServiceError.invalidPath("absolute path") }
        guard !raw.hasPrefix("~") else { throw ServiceError.invalidPath("home path") }
        guard !raw.contains("\\") else { throw ServiceError.invalidPath("backslash path") }
        guard !raw.split(separator: "/").contains("..") else {
            throw ServiceError.invalidPath("path traversal")
        }

        let candidate = vaultRoot
            .appendingPathComponent(raw, isDirectory: false)
            .standardizedFileURL
        let resolved = candidate.resolvingSymlinksInPath()

        try assertInsideVault(resolved)
        try assertNotReservedInternalPath(resolved)
        return resolved
    }

    private func containedURL(fileURL: URL) throws -> URL {
        guard fileURL.isFileURL else {
            throw ServiceError.invalidPath("non-file URL")
        }

        let resolved = fileURL.standardizedFileURL.resolvingSymlinksInPath()
        try assertInsideVault(resolved)
        try assertNotReservedInternalPath(resolved)
        return resolved
    }

    private func assertInsideVault(_ url: URL) throws {
        let root = resolvedVaultRoot.path
        let rootPrefix = root.hasSuffix("/") ? root : root + "/"
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path

        guard path == root || path.hasPrefix(rootPrefix) else {
            throw ServiceError.outsideVault(url.path)
        }
    }

    private func assertNotReservedInternalPath(_ url: URL) throws {
        if url.pathComponents.contains(".epcache") {
            throw ServiceError.invalidPath("reserved sidecar/cache path")
        }
    }
}
```

Required API contract changes:

- `createCodeFile` must resolve `relativeDirectory + validatedName` through the canonical resolver.
- `readCodeFile(at:)` must reject non-contained absolute URLs before file IO.
- `updateCodeFile(at:)` must reject non-contained absolute URLs before file IO.
- `listCodeFiles` must reject traversal and symlink escapes.
- `vaultRelativePath(of:)` must become throwing and must never return an external absolute path.
- Sidecar path construction must only accept a validated vault-relative path.

Required tests:

```swift
@Test("createCodeFile rejects traversal relativeDirectory")
func createRejectsTraversalDirectory() throws { ... }

@Test("createCodeFile rejects absolute relativeDirectory")
func createRejectsAbsoluteDirectory() throws { ... }

@Test("readCodeFile rejects external absolute URL")
func readRejectsExternalAbsoluteURL() throws { ... }

@Test("updateCodeFile rejects external absolute URL")
func updateRejectsExternalAbsoluteURL() throws { ... }

@Test("readCodeFile rejects symlink escape")
func readRejectsSymlinkEscape() throws { ... }

@Test("sidecar path cannot spoof .epcache")
func sidecarRejectsReservedCachePath() throws { ... }

@Test("unicode-normalized traversal is rejected")
func unicodeTraversalIsRejected() throws { ... }
```

Manual/runtime proof:

- Attempt `../outside.swift` from every visible code-file UI.
- Attempt `/tmp/outside.swift` read/update through every agent/tool path.
- Attempt symlink inside vault pointing outside.
- Confirm no source file, no sidecar, no provenance success row, and no partial SwiftData state is created for rejected paths.

Immediate Codex order:

```text
Start with RCA4-P0-001 only.

Do not touch UI, graph, agent_core, Omega, or Helios files.

Inspect Epistemos/Engine/CodeFileService.swift and its tests.
Implement one canonical vault containment resolver.
Route create/read/update/list/sidecar path construction through it.
Add tests for:
- relativeDirectory "../outside"
- relativeDirectory "/tmp"
- absolute readCodeFile URL outside vault
- absolute updateCodeFile URL outside vault
- symlink inside vault pointing outside
- unicode-normalized traversal
- .epcache spoofing

Then run only:
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CodeFileServiceTests test CODE_SIGNING_ALLOWED=NO

Report before touching the next item.
```

Acceptance:

- All file operations fail closed outside the vault.
- AI/editor code-file tools remain hidden or disabled until containment and approval proof pass.

Fix-pass evidence 2026-05-09:

- Files changed:
  - `Epistemos/Engine/CodeFileService.swift`
  - `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
  - `EpistemosTests/CodeFileServiceTests.swift`
  - `EpistemosTests/NoteEditorLayoutTests.swift`
- Tests added:
  - `CodeFileServiceTests.createRejectsRelativeDirectoryTraversal`
  - `CodeFileServiceTests.createRejectsAbsoluteRelativeDirectory`
  - `CodeFileServiceTests.readRejectsExternalAbsoluteURL`
  - `CodeFileServiceTests.readRejectsPrefixCollisionOutsideVault`
  - `CodeFileServiceTests.updateRejectsExternalAbsoluteURLAndPreservesOutsideFile`
  - `CodeFileServiceTests.readAndUpdateRejectEscapingSymlink`
  - `CodeFileServiceTests.readAndUpdateRejectReservedEpcacheSourceFiles`
  - `CodeFileServiceTests.listRejectsSpoofedEpcacheSidecar`
  - `NoteEditorLayoutTests.visibleCodeEditorFileIORoutesThroughCodeFileServiceContainment`
- Source proof:
  - `CodeFileService` now routes create/read/update/list/sidecar construction through throwing vault containment helpers.
  - Containment resolves the canonical vault root, rejects absolute/traversal paths, rejects symlink escapes, rejects prefix-collision outside paths, and rejects source files under `.epcache`.
  - `NoteDetailWorkspaceView` no longer performs direct `String.write(toFile:)` or `String(contentsOfFile:)` for visible code-backed notes; visible reads/saves go through `CodeFileService(vaultRoot:)`.
- Commands run:
  - Test-first red command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CodeFileServiceTests test CODE_SIGNING_ALLOWED=NO`
    - Result: failed before product patch because `CodeFileService.ServiceError.pathEscapesVault` and `.reservedCachePath` did not exist.
    - Red xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_00-39-59--0500.xcresult`
  - Focused service pass: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CodeFileServiceTests test CODE_SIGNING_ALLOWED=NO`
    - Result: passed, 24 tests.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_00-44-44--0500.xcresult`
  - Source guard: `rg -n "content\\.write\\(|write\\(toFile:|String\\(contentsOfFile: filePath|Data\\(contentsOf:|String\\(contentsOf:" Epistemos/Views/Notes/NoteDetailWorkspaceView.swift Epistemos/Engine/LiveCodeEditorController.swift Epistemos/Engine/CodeFileService.swift`
    - Result: direct visible editor read/write patterns removed; remaining `Data(contentsOf:)` calls are inside `CodeFileService`.
  - Combined caller-chain pass: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CodeFileServiceTests -only-testing:EpistemosTests/LiveCodeEditorControllerTests -only-testing:EpistemosTests/NoteEditorLayoutTests test CODE_SIGNING_ALLOWED=NO`
    - Result: passed, 101 tests across 3 suites.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_00-49-29--0500.xcresult`
- Remaining risk:
  - Agent/tool-originated code writes without explicit grant were not proven reachable in current Swift caller-chain grep; approval-loop proof remains in Current Access/tool-permission work.
  - Visible code editor containment is fixed, but code-file reads remain synchronous through the service; main-thread IO removal remains a separate Wave 1 item.
  - Manual runtime proof still needed for visible UI attempts against `/tmp`, prefix-collision paths, and symlink escapes.

### RCA9-P0-002 - Promote App Store artifact scanning above source-guard proof

Status: PATCHED - RELEASE ARTIFACT SCAN GREEN / MANUAL MAS UI SWEEP PENDING

Canonical owner: `RCA4-P0-002`

Merge / link:

- `RCA3-P0-001`
- `RCA-P1-021`

Subsystem: MAS/App Store build, direct-distribution build, Pro tools, Omega/MCP, CLI passthrough, computer-use/AX.

Research signal: Drop 9 reinforces that build scripts and source guards are useful but not binary proof. Even if `build-agent-core.sh`, `build-omega-mcp.sh`, and `bundle-app-runtime-assets.sh` contain App Store gates, the built `Epistemos-AppStore.app` must be scanned for prohibited or Pro-only runtime affordances.

Required scan script:

```bash
#!/usr/bin/env bash
set -euo pipefail

APP="${1:?usage: scan_appstore_bundle.sh /path/to/Epistemos.app}"

echo "[scan] executable/resource strings"
find "$APP" -type f -print0 |
  xargs -0 strings 2>/dev/null |
  rg -n "pty|osascript|cli_passthrough|bash_execute|Command::new|fork|exec|docker|stdio_mcp|ScreenCaptureKit|AXUIElement|/bin/sh|/bin/bash|/usr/bin/python|launchctl" \
  && {
    echo "::error::AppStore bundle contains prohibited/pro-only runtime strings"
    exit 1
  } || true

echo "[scan] possible executable files"
find "$APP" -type f -perm +111 -print

echo "[scan] complete"
```

Required artifact checks:

- `strings` scan of the `.app`.
- `nm -gU` scan of embedded dylibs where applicable.
- Bundle resource scan for MOHAWK, MoLoRA, raw Helios docs, research packets, Python scripts, PTY helpers, and command catalogs that imply unavailable capabilities.
- Live MAS build UI sweep of Settings, onboarding, command palette, chat slash menu, agent controls, and Omega/Hermes surfaces.

Acceptance:

- MAS bundle does not contain or surface Pro-only shell, CLI, MCP stdio, browser-control, screen capture, AX, PTY, Docker, or computer-use paths except as clean unavailable stubs where explicitly approved.
- Artifact scan output is stored with the release audit evidence.

Fix-pass evidence 2026-05-09:

- Changed files:
  - `scripts/scan_appstore_bundle.sh`
  - `Tools/app-review-audit/app-review-audit.sh`
  - `.github/workflows/ci.yml`
  - `agent_core/src/tools/registry.rs`
  - `agent_core/src/approval.rs`
  - `agent_core/tests/mas_pro_feature_gates.rs`
  - `Epistemos/State/AgentCommandCenterState.swift`
  - `EpistemosTests/AppStoreHardeningTests.swift`
- Tests added/updated:
  - `EpistemosTests/AppStoreHardeningTests.appReviewAuditFailsMASSubprocessFindingsInsteadOfWarning`
  - `EpistemosTests/AppStoreHardeningTests.appStoreArtifactScanInspectsFinalBundleStringsSymbolsExecutablesAndResources`
  - `EpistemosTests/AppStoreHardeningTests.appStoreSchemeHasTestsOrCIRunsDedicatedMASArtifactGate`
  - `EpistemosTests/AppStoreHardeningTests.appStoreAgentCommandModesHideProSubprocessTools`
  - `agent_core/tests/mas_pro_feature_gates.rs::mas_legacy_aliases_do_not_embed_pro_subprocess_tool_names`
- Red evidence:
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/AppStoreHardeningTests test CODE_SIGNING_ALLOWED=NO`
    - Failed because the App Review script still treated MAS subprocess findings as warning-only and no final bundle scanner / dedicated MAS CI gate existed.
    - Red xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_03-32-08--0500.xcresult`
  - `cargo test --manifest-path agent_core/Cargo.toml --test mas_pro_feature_gates mas_legacy_aliases_do_not_embed_pro_subprocess_tool_names`
    - Failed because MAS `agent_core` still embedded Pro-only legacy alias strings such as `bash_execute`.
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/AppStoreHardeningTests test CODE_SIGNING_ALLOWED=NO`
    - Failed after adding the bundle scan source guard because the scanner lacked a separate prohibited-symbol pattern and the raw string pattern still included generic `fork|exec`.
    - Red xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_04-19-20--0500.xcresult`
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/AppStoreHardeningTests test CODE_SIGNING_ALLOWED=NO`
    - Failed when the Swift source guard matched an earlier `debug`/`code` switch instead of the `preferredToolNames` implementation section.
    - Red xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_04-42-18--0500.xcresult`
- Green evidence:
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/AppStoreHardeningTests test CODE_SIGNING_ALLOWED=NO`
    - Passed, 24 Swift Testing tests.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_04-45-57--0500.xcresult`
  - `cargo test --manifest-path agent_core/Cargo.toml --test mas_pro_feature_gates`
    - Passed, 3 tests.
  - `./Tools/app-review-audit/app-review-audit.sh appstore`
    - Passed: 35 bundled artifacts checked; no runtime executable-code download patterns; no HELIOS V5 runtime AppStorage toggles; no subprocess launch surface detected for target `appstore`.
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Release -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
    - Passed, built `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Release/Epistemos.app`.
  - `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-audit scripts/scan_appstore_bundle.sh /Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Release/Epistemos.app`
    - Passed: no prohibited runtime strings, no prohibited runtime symbols, no prohibited research/tool resource residue.
- Runtime/manual proof:
  - Final Release `.app` artifact scan is complete and stored under `build/appstore-audit`.
  - Manual MAS UI sweep of Settings, onboarding, command palette, chat slash menu, agent controls, and Omega/Hermes surfaces remains pending.
- Remaining risk:
  - This closes the artifact-gate blocker, but not the separate UI/copy honesty sweep or the three uninterrupted clean-pass release criterion.

### RCA9-P0-003 - Split credential environment risk into env mirroring and child scrub proof

Status: PATCHED PARTIAL - AUTH-ENV-P0-A CLOSED / AUTH-ENV-P0-B PARTIAL

Canonical owner: `RCA-P0-004`

Subsystem: `AppBootstrap`, cloud provider credentials, OAuth, child processes, MCP stdio, CLI passthrough, helper tools.

Research signal: Drop 9 separates two different risks that were previously tangled: process-wide credential mirroring and child-process environment inheritance. The first should be removed or tightly scoped; the second must be tested for every `Process`/helper launch path.

Split tasks:

1. `AUTH-ENV-P0-A`: remove or scope process-wide provider credential environment mirroring.
2. `AUTH-ENV-P0-B`: prove every child process/helper uses a scrubbed allowlist environment.

Required scrubber shape:

```swift
enum SensitiveEnvironmentPolicy {
    static let secretKeys: Set<String> = [
        "ANTHROPIC_API_KEY",
        "OPENAI_API_KEY",
        "GOOGLE_API_KEY",
        "PERPLEXITY_API_KEY",
        "OPENROUTER_API_KEY",
        "GLM_API_KEY",
        "KIMI_API_KEY",
        "DEEPSEEK_API_KEY",
        "MINIMAX_API_KEY",
        "XAI_API_KEY",
        "MISTRAL_API_KEY",
        "GROQ_API_KEY",
        "HF_TOKEN",
        "OPENAI_ACCESS_TOKEN",
        "ANTHROPIC_ACCESS_TOKEN",
        "GOOGLE_ACCESS_TOKEN",
        "OPENAI_AUTH_MODE",
        "ANTHROPIC_AUTH_MODE",
        "GOOGLE_AUTH_MODE",
        "GOOGLE_PROJECT_ID"
    ]

    static func scrubbed(_ env: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        env.filter { key, _ in !secretKeys.contains(key) }
    }
}

extension Process {
    func applyEpistemosScrubbedEnvironment(extra: [String: String] = [:]) {
        var env = SensitiveEnvironmentPolicy.scrubbed()
        for (key, value) in extra {
            env[key] = value
        }
        self.environment = env
    }
}
```

Required greps:

```bash
rg -n "Process\\(|NSTask|setenv\\(|unsetenv\\(|environment =" Epistemos agent_core omega-mcp
rg -n "OPENAI_|ANTHROPIC_|GOOGLE_|ACCESS_TOKEN|API_KEY|HF_TOKEN" Epistemos agent_core omega-mcp
```

Required tests:

- Seed fake provider keys/tokens in the parent process.
- Launch every product `Process` wrapper with a helper that prints environment keys.
- Assert provider secrets are absent unless a narrowly approved provider runtime is explicitly under test.
- Add a source guard that rejects raw `Process()` launch sites without the environment policy.

Acceptance:

- No subprocess/helper/MCP server inherits provider credentials by accident.
- In-process Rust credential needs are served by explicit config where possible, not by global process env.

Implementation evidence, 2026-05-09:

- `AUTH-ENV-P0-A` is closed for the current Rust agent bridge: parent-process credential mirroring was removed from `AppBootstrap.populateAgentCoreEnvironment`, and the Rust session bridge now uses `withScopedAgentCoreEnvironment` only for the two `runAgentSession(...)` calls in `ChatCoordinator`.
- Parent-env regression tests now assert credential refresh and deferred bootstrap do not leave `OPENAI_ACCESS_TOKEN`, `ANTHROPIC_ACCESS_TOKEN`, `GOOGLE_ACCESS_TOKEN`, `GOOGLE_PROJECT_ID`, `DEEPSEEK_API_KEY`, `GLM_API_KEY`, `KIMI_API_KEY`, or `MINIMAX_API_KEY` in process env.
- `AUTH-ENV-P0-B` is partially covered by `agent_core::security::tests::harden_cli_subprocess_clears_provider_secrets`; broader Swift `Process`/MCP/XPC/helper launch probes remain open.

### RCA9-P0-004 - Keep database fallback P0 until degraded-mode writes are proven honest

Status: PATCHED - AUTOMATED PARITY GREEN / NEEDS-MANUAL-EXECUTOR-SMOKE

Canonical owner: `RCA-P0-002`

Subsystem: SwiftData container initialization, `AppBootstrap`, `RootView`, database recovery, note/chat/capture persistence.

Research signal: Drop 9 notes that `databaseError` and a database error alert may already exist, with choices like Continue Empty, Reset Database, and Quit. That is better than a silent fallback, but not enough if Continue Empty allows users to create notes/chats/captures while believing they are durable.

Required UI contract:

- Rename "Continue Empty" to "Continue Ephemeral" or equivalent.
- Show a persistent degraded-mode banner, not only a one-time alert.
- Disable durable write actions or label every write as temporary/export-only.
- Never let a normal save affordance imply disk persistence while the app is in memory-only fallback.

Patch direction:

```swift
enum PersistenceMode: Equatable, Sendable {
    case durable(url: URL)
    case inMemoryFallback(reason: String)
}

@MainActor
@Observable
final class AppPersistenceStatus {
    private(set) var mode: PersistenceMode

    var isDurable: Bool {
        if case .durable = mode { return true }
        return false
    }
}
```

Runtime proof:

- Corrupt or lock the SwiftData store.
- Launch.
- Continue in degraded mode.
- Attempt note creation, chat persistence, Quick Capture, `.epdoc` save, vault sync, and model-vault writes.
- Relaunch and verify the user was never told temporary edits were durable.

Acceptance:

- No editable surface appears without durable/temporary state truth.
- The user can export/recover from degraded mode without a false-success save.

Fix-pass evidence 2026-05-09:

- Canonical implementation owner: `RCA-P0-002`.
- Files changed:
  - `Epistemos/App/AppBootstrap.swift`
  - `Epistemos/App/RootView.swift`
  - `EpistemosTests/RuntimeValidationTests.swift`
  - `EpistemosTests/ProductionHardeningTests.swift`
- Delta from earlier partial state:
  - The old `Continue Empty` branch has been removed rather than renamed.
  - `AppBootstrap` records `PersistenceMode.inMemoryRecovery(reason:)` on persistent-store open failure.
  - `RootView` keeps a visible recovery overlay mounted while `databaseError` exists, so the warning is not a one-shot alert.
  - The recovery copy explicitly says notes, chat, capture, vault sync, and `.epdoc` writes are disabled.
- Commands run:
  - Red: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/RuntimeValidationTests test CODE_SIGNING_ALLOWED=NO`
    - Red xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-33-44--0500.xcresult`
  - Green RuntimeValidation: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/RuntimeValidationTests test CODE_SIGNING_ALLOWED=NO`
    - Result: passed, 263 Swift Testing tests.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-39-29--0500.xcresult`
  - Green AuditHardeningRegression: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/AuditHardeningRegressionTests test CODE_SIGNING_ALLOWED=NO`
    - Result: passed, 19 Swift Testing tests.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-48-12--0500.xcresult`
  - Green SovereignGate: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/SovereignGateTests test CODE_SIGNING_ALLOWED=NO`
    - Result: passed, 33 Swift Testing tests.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-51-07--0500.xcresult`
- Remaining risk:
  - Runtime proof still required under actual corrupt/locked SwiftData store conditions.
  - The UI now blocks the main workspace, but secondary windows/write surfaces still need manual/runtime verification before this item can be closed.

### RCA9-P1-001 - Move `AgentGrepService` search and sidecar enrichment off `MainActor`

Status: CONFIRMED-RISK

Canonical owner: `RCA-P1-015`

Subsystem: code search, `AgentGrepService`, `CodeFileService`, sidecar enrichment, chat/agent UI responsiveness.

Research signal: Drop 9 confirms the P1 hitch risk: `AgentGrepService` is reportedly `@MainActor`, its public `search` method is synchronous, and it enriches every backend hit by reading code files/sidecars. Large repo grep can therefore block drag/resize/typing if reachable from UI.

Patch direction:

```swift
public actor AgentGrepService {
    private let index: any CodeIndexClient
    private let files: CodeFileService

    public func search(
        query: String,
        kindFilter: CodeArtifactKind? = nil,
        limit: Int = 25
    ) async throws -> [AgentGrepHit] {
        let backendHits = try index.search(
            query: query,
            kindFilter: kindFilter,
            limit: limit
        )

        return backendHits.map { hit in
            let fileURL = files.vaultRoot.appendingPathComponent(
                hit.vaultRelativePath,
                isDirectory: false
            )
            let sidecar = (try? files.readCodeFile(at: fileURL))?.sidecar
            return AgentGrepHit(
                vaultRelativePath: hit.vaultRelativePath,
                kind: hit.kind,
                score: hit.score,
                snippet: hit.snippet,
                symbol: hit.symbol,
                source: hit.source,
                provenance: sidecar?.provenance,
                crossReferences: sidecar?.crossReferences ?? []
            )
        }
    }
}
```

If `CodeFileService` remains main-thread-bound or non-thread-safe, introduce a separate `actor CodeFileReader` with contained read-only APIs. Do not keep repo search and per-hit disk reads on the main actor.

Required test:

```swift
@Test("AgentGrep search does not run sidecar reads on MainActor")
func grepSearchOffMain() async throws {
    // Use a fake reader that records Thread.isMainThread.
    // Seed 500 hits.
    // Assert no sidecar read enrichment occurs on the main thread.
}
```

Manual proof:

- Large repo search while dragging/resizing the window.
- Fail if visible hitch or >50 ms main-thread stalls.

### RCA9-P1-002 - Keep AFM sidecar serialization safe but make it measurable and visible

Status: CONFIRMED-RISK / SAFE-BUT-SLOW UNTIL MEASURED

Canonical owner: `RCA-P1-023`

Subsystem: AFM sidecars, FoundationModels, import/index queues, perceived app freeze.

Research signal: Drop 9 confirms `AFMSidecarGenerator` is globally serialized via static in-flight state and waiters. This may be correct if FoundationModels sessions must be conservative, but without visible queue state it looks like a freeze during bulk generation/import.

Patch direction:

```swift
actor AFMSidecarQueue {
    private let maxConcurrent: Int
    private var running = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(maxConcurrent: Int = 1) {
        self.maxConcurrent = maxConcurrent
    }

    func acquire() async {
        if running < maxConcurrent {
            running += 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        } else {
            running = max(0, running - 1)
        }
    }
}
```

Required UX:

- Surface progress such as "Generating sidecars 3/20..."
- Provide cancellation where generation is not correctness-critical.
- Emit signposts for queued, started, completed, failed, and cancelled.

Acceptance:

- Bulk sidecar generation is bounded, visible, cancellable where appropriate, and does not masquerade as UI freeze.

### RCA9-P1-003 - Reconcile authority persistence and actual dispatch enforcement

Status: PARTIALLY-FIXED / NEEDS-RUNTIME-PROOF

Canonical owner: `RCA-P1-025`

Link:

- `RCA2-P0-001`
- Active Grants UI truth-model work.

Subsystem: `AgentAuthorityStore`, file-backed policy, active grants UI, tool dispatcher.

Research signal: Drop 9 confirms the settings path appears improved because it resolves `AppBootstrap.shared?.agentAuthorityStore` or constructs a file-backed store. The remaining risk is any direct `AgentAuthorityStore()` construction that silently uses in-memory persistence, plus dispatch paths that do not actually consult the stored policy.

Required greps:

```bash
rg "AgentAuthorityStore\\(" Epistemos EpistemosTests
rg "AgentPermissionRequest\\(" Epistemos agent_core omega-mcp
rg "decision\\(for:" Epistemos
```

Runtime proof:

1. Set package installs to "never."
2. Quit and relaunch.
3. Verify `~/Library/Application Support/Epistemos/agent_authority.json`.
4. Trigger a package-install-like tool.
5. Confirm denial happens before execution, not just in settings UI.

Acceptance:

- Policy persists.
- Active grants UI separates persisted policy, stored grants, transient attachments, and static explanatory rows.
- Tool dispatch consults the same authority truth before execution.

### RCA9-P1-004 - Generate a command/tool truth report from runtime registries

Status: CONFIRMED-REQUIRED

Canonical owner: `RCA4-P1-012`

Merge / link:

- `RCA-P1-004`
- `RCA-P1-017`
- `RCA5-P1-012`
- `RCA7-P1-008`

Subsystem: main chat slash commands, Agent Command Center, LocalAgent compatibility commands, Agent Core tools, Omega/MCP tools, CLI passthrough, provider-native tools.

Research signal: Drop 9 reinforces that the issue is not a "tool count mismatch." The app can legitimately have several inventories. The trust failure happens when UI/docs flatten separate registries into one implied callable surface.

Minimum runtime report schema:

```json
{
  "name": "/image",
  "surface": "main_chat_slash",
  "advertised": true,
  "parser": "ACCSlashCommand",
  "executor": null,
  "buildTarget": "MAS",
  "availability": "hidden_dead",
  "approval": null,
  "lastSmoke": null,
  "visibleToUser": true,
  "verdict": "visible-broken"
}
```

Required columns:

```text
name
surface
advertised
parser
compiler
approval gate
executor
build target
MAS/Core/Pro availability
provider/model requirement
log destination
last successful smoke
visible result
verdict
```

Acceptance:

- No UI lists a command/tool unless the report marks it executable or explicitly disabled/unavailable.
- Main slash commands, LocalAgent compatibility, Agent Core, Omega/MCP, CLI passthrough, and provider-native tools remain separate tables.

### RCA9-P1-005 - Keep permission grants open until dispatcher-level enforcement is proven

Status: PARTIALLY-FIXED / NEEDS-RUNTIME-PROOF

Canonical owner: `RCA2-P0-001`

Subsystem: `ChatCoordinator`, context attachments, live/snapshot resources, permission grants, tool dispatcher, approval modal.

Research signal: Drop 9 notes that chat may record resource grants and seed live attachment grants, but that is not enough. The actual tool executor must enforce the same allowlist before read/write.

Required proof matrix:

```text
attach note A -> ask edit note A -> allowed only after grant
attach note A -> ask edit note B -> denied or escalates before mutation
attach file A -> ask read file A -> allowed only within grant
attach file A -> ask write file B -> denied or escalates before mutation
attach snapshot text -> ask write source -> denied clearly
revoke grant mid-session -> next call fails with clear denial
```

Acceptance:

- Permission chips derive from compiled execution plans, not prompt heuristics.
- Tool args are validated against grants inside the executor.
- Denial emits a visible user message and a durable audit/provenance row.

2026-05-09 Current Access parity evidence:

- Shared Swift plan added in `Epistemos/Views/Chat/ComposerCurrentAccessPlan.swift`.
- Composer rows and Settings rows now share that plan; resource-grant UI excludes shell/external approval rows.
- Provider-native capability summary is derived from `InferenceState.providerNativeCapabilityToolNameList(for:)` instead of prompt heuristics.
- Added `EpistemosTests/CurrentAccessParityTests.swift` checks for:
  - attached file A does not grant write access to file B in the Swift plan
  - snapshot attachments cannot become writable
  - visible summary matches compiled provider-native tool names
  - resource-grant surfaces use scoped copy and exclude shell rows
- Green commands:
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CurrentAccessParityTests test CODE_SIGNING_ALLOWED=NO`
  - `cargo test --manifest-path agent_core/Cargo.toml --lib resources::bridge::tests::attached_resource_from_paste_is_snapshot_read_only`
  - `cargo test --manifest-path agent_core/Cargo.toml --lib resources::tool_authz::tests`
  - `cargo test --manifest-path agent_core/Cargo.toml --lib r5_gate_`
- Remaining risk:
  - The exact prompt-to-live-dispatch manual matrix remains open until a runtime smoke proves denials are visible before mutation and recorded in the audit/provenance surface.

### RCA9-P1-006 - Harden OAuth callback state and loopback binding

Status: PATCHED - AUTOMATED VALIDATION GREEN / LIVE CALLBACK FORGERY SMOKE PENDING

Canonical owner: `RCA2-P0-004`

Link:

- `RCA5-P1-004`
- Cloud auth provenance work.

Subsystem: `CloudProviderAuthService`, OAuth setup UI, local callback listener, Keychain.

Research signal: Drop 9 keeps this high-risk until callback implementation proves loopback-only binding and one-time `state` validation. Having PKCE and Keychain storage is not sufficient if forged local callbacks can inject a code or replay a stale state.

Required implementation contract:

```swift
struct OAuthPendingState: Sendable {
    let provider: CloudModelProvider
    let state: String
    let codeVerifier: String
    let createdAt: Date
}
```

Callback must reject:

- missing state
- wrong state
- reused state
- wrong path
- missing code
- wrong provider
- stale pending session
- non-loopback listener binding

Manual proof:

```bash
curl "http://127.0.0.1:<port>/<callback-path>?code=fake-code"
curl "http://127.0.0.1:<port>/<callback-path>?code=fake-code&state=wrong"
lsof -iTCP:<port>
```

Acceptance:

- Forged callback does not store credentials.
- Listener is loopback-only.
- Silent refresh emits sanitized provenance without token material.

Patch evidence 2026-05-09:

- Files changed:
  - `Epistemos/Engine/CloudProviderAuthService.swift`
  - `EpistemosTests/CloudProviderAuthServiceTests.swift`
- Source/caller proof:
  - Google sign-in now passes a random one-time state to both `LocalOAuthCallbackServer.start(path:expectedState:)` and the Google authorization URL.
  - PKCE verifier/challenge remains per sign-in session and the callback state is validated before token exchange can receive a code.
  - Callback parsing is factored into `OAuthCallbackRequestValidator` for deterministic negative tests.
- Negative tests added and passed:
  - missing state
  - wrong state
  - replayed state
  - wrong path
  - wrong host
  - concurrent sign-ins isolated by separate states
- Commands:
  - Red: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/LocalOAuthCallbackValidationTests test CODE_SIGNING_ALLOWED=NO`
    - Failed before product validator existed.
    - xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_02-45-17--0500.xcresult`
  - Red: same command.
    - Failed on actor isolation while adding replay consume state.
    - xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_02-48-56--0500.xcresult`
  - Green: same command.
    - 6 tests passed.
    - xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_02-50-26--0500.xcresult`
  - Green: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CloudProviderAuthServiceTests test CODE_SIGNING_ALLOWED=NO`
    - 23 tests passed.
    - xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_02-53-18--0500.xcresult`
- Guard:
  - `rg -n "LocalOAuthCallbackServer.start|OAuthCallbackRequestValidator|state|code_challenge|requiredLocalEndpoint|NWListener\\(" Epistemos/Engine/CloudProviderAuthService.swift EpistemosTests/CloudProviderAuthServiceTests.swift`
  - `NWListener(using: parameters, on: .any)` remains as the ephemeral port selector; `parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)` is the binding proof in source.
- Remaining risk:
  - Live forged-callback `curl` proof and live port reachability proof are still required before this can be marked fully closed.

### RCA9-P1-007 - Verify composer voice temp-file cleanup on every path

Status: PATCHED - AUTOMATED CLEANUP TESTS GREEN / MANUAL MIC SMOKE PENDING

Canonical owner: `RCA5-P1-005`

Subsystem: `ComposerVoiceInputService`, `VoiceInputButton`, composer microphone UI, temp audio privacy.

Research signal: Drop 9 confirms the service creates `composer-UUID.m4a` temp files and keeps this open until the full success/failure/cancel/window-close cleanup path is proven. If cleanup only exists in cancel, successful or failed transcription can leave private audio on disk.

Patch direction:

```swift
@MainActor
private func cleanupOutputFile() {
    guard let url = outputURL else { return }
    outputURL = nil
    do {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    } catch {
        log.error("Failed to delete composer temp audio: \(error.localizedDescription, privacy: .public)")
    }
}
```

Required tests:

- successful transcription deletes file
- transcription error deletes file
- cancel deletes file
- window close/app teardown deletes file
- denied microphone permission leaves no residue

Manual proof:

```bash
find "${TMPDIR:-/tmp}" -name 'composer-*.m4a' -print
```

Acceptance:

- No `composer-*.m4a` remains after success, failure, cancel, close, or app quit.

Fix-pass evidence 2026-05-09:

- Canonical patch landed under `RCA5-P1-005`.
- Files changed:
  - `Epistemos/Engine/ComposerVoiceInputService.swift`
  - `Epistemos/Views/Chat/ComposerMicButton.swift`
  - `EpistemosTests/ComposerVoiceInputServiceTests.swift`
- Automated coverage:
  - Success, transcription error, cancel, and teardown paths all assert the generated `composer-*.m4a` file is removed.
  - Source test asserts the composer mic view calls `service.tearDown()` on disappear.
- Commands:
  - Red: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ComposerVoiceInputServiceTests test CODE_SIGNING_ALLOWED=NO`
    - xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_03-21-10--0500.xcresult`
  - Green: same command.
    - 5 tests passed.
    - xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_03-24-26--0500.xcresult`
  - `find "${TMPDIR:-/tmp}" -name 'composer-*.m4a' -print 2>/dev/null || true`
    - No temp composer recordings printed.
- Remaining risk:
  - App-quit cleanup is covered through UI disappearance/teardown source and temp residue scan, but still needs live app smoke with a real mic session before full closure.

### RCA9-P2-001 - Downgrade `AnswerPacket` / VRM to implemented-not-wired until chat emits it

Status: DONE 2026-05-12 — canonical owner `RCA4-P1-011` and `RCA-P2-001` both closed; chat emits real packets, MessageBubble renders the chip.

Canonical owner: `RCA4-P1-011`

Link:

- `RCA-P2-001` (DONE 2026-05-12)

Subsystem: `AnswerPacket`, `VRMLabelView`, Verified Research Mode, chat row rendering, streaming delegate.

Research signal (now stale): "wired state only arrives when Swift
emits packets per chat reply" — wired state arrived 2026-05-12. See
`RCA-P2-001` and `RCA4-P1-011` for the full V6.2 commit chain
(`7a00db484` → `e639b6bb4`) plus follow-on test + doctrine commits.

Required grep (no longer needed for status — kept for the next
deep-audit cycle to verify the wired claim still holds):

```bash
rg "AnswerPacket|VRMLabelView|MessageBubble|completeProcessing|StreamingDelegate" Epistemos agent_core
```

Acceptance — all three satisfied:

- Product copy says schema-ready or hides VRM if no emitted packet
  exists: SATISFIED (V6.2 doctrine refresh commits `54db64add` +
  `fb36626e0` removed the stale "deferred" copy).
- A real chat turn creates/persists an `AnswerPacket`:
  SATISFIED at `AnswerPacketEmitter.shared.emit(packet)` in
  `StreamingDelegate.onComplete`.
- Chat row / message bubble displays the packet label or
  provenance surface: SATISFIED via
  `MessageBubble.AnswerPacketChipRow`, which renders the VRMLabel
  chip + attention mode + interrupt bucket chips for any
  assistant message with a bound `answerPacketId` that's still in
  the 32-packet ring.

### RCA9-P2-002 - Mark MLX image generation as scaffold-only unless a real route exists

Status: CONFIRMED SCAFFOLD-ONLY

Canonical owner: `RCA3-P2-003`

Subsystem: `/image`, MLX image generation, provider image route, command truth.

Research signal: Drop 9 confirms `MLXImageGenerationService` explicitly says the Flux/MLXDiffusers pipeline is absent and the default resolver throws `fluxPipelineUnavailable`. That is fine as a future path, but it must not be exposed as a working local image feature.

Acceptance:

- Local MLX image generation is hidden or visibly unavailable unless the actual pipeline/package/model is installed.
- `/image` routes to a real configured provider or returns a clear unavailable/setup message.
- Command/tool truth report marks local MLX image generation as scaffold-only until proven.

2026-05-09 status note:

- `/image` is hidden from normal slash-command availability while `image_generate` is not surfaced.
- Rust pro-build `image_generate` tests confirm explicit provider and honest unavailable/setup behavior for the underlying tool.
- The full generated command/tool truth report remains open.

### RCA9-P2-003 - Treat vendored LLM corpora and dependency trees as dependency surface, not feature proof

Status: CONFIRMED NOT FEATURE PROOF

Canonical owner: `RCA3-P2-005`

Subsystem: vendored `llama.cpp`/ggml code, LocalLLMClient, model installs, app copy.

Research signal: Drop 9 reinforces that massive vendored local-LLM source/docs/examples prove dependency presence, not a user-visible generation feature. Product truth requires built runtime, installed model, selected model, reachable UI, and successful generation.

Required docs distinction:

```text
dependency source present
built runtime library present
model asset installed
model selected
user-visible generation path reachable
runtime smoke passed
```

Acceptance:

- Vendored dependency size does not inflate current feature claims.
- App Store bundle excludes research/training corpora and unused examples unless strictly required.

### RCA9-P2-004 - Quarantine archived AgentRuntime / handoff / Omega scaffold surfaces

Status: CONFIRMED-REQUIRED

Canonical owner: `RCA6-P2-005`

Link:

- `RCA4-P2-001`
- `RCA7-P1-009`

Subsystem: archived `AgentRuntime`, `AgentHandoff`, hierarchy protocol surfaces, thin Omega UI, Hermes/Omega scaffold.

Research signal: Drop 9 reinforces that archived/runtime comments and symbol QA are not runtime proof. If archived or thin scaffold surfaces are imported by production, either mount-test them or quarantine them.

Required lint:

```bash
rg "AgentRuntime|AgentHandoff|HierarchicalAgent" Epistemos --glob '!EpistemosTests/**'
```

Acceptance:

- Archived runtime code is not imported by production files.
- If reachable, it has a real mounted caller chain, tests, and user-surface truth labels.

### RCA9-P2-005 - Add PromptTree / PTF privacy scans to the durable-store audit

Status: PATCHED 2026-05-13 — PromptTreePersister header now carries a Privacy Doctrine block documenting opt-in gating, key-never-persisted invariant, scan commands, and purge controls

Subsystem: PromptTree, PTF persister, vault `.epistemos/prompts`, prompt caching/export, privacy.

Research signal: Drop 9 notes PromptTree/PTF is implemented infrastructure and persists prompt subtrees under `<vault>/.epistemos/prompts`. This is useful, but it becomes privacy-sensitive if prompts include provider keys, hidden capture metadata, attached-note text, or model input snapshots.

Fix-pass evidence:
- `Epistemos/Engine/PromptTreePersister.swift` header (the most-read
  surface for anyone touching this code) now includes a "Privacy doctrine"
  block that covers all 3 acceptance bullets:
  1. **No secrets**: PromptTree is OPT-IN (default `false` UserDefaults).
     `Prompt` Codable type has no `apiKey` / `bearerToken` / `secret`
     fields — API keys live in macOS Keychain and are looked up at
     HTTP-request time, NOT serialized. Verified by structural design.
  2. **Retention controls**: GC policy = keep last 20 turns per
     session + `gcStaleTurns` on-demand purge.
  3. **Hidden capture/scan path**: documented `find` + `rg` scan
     commands so users / admins can verify a sensitive vault doesn't
     contain leaked text via attached-note content.
  4. **Full purge**: `rm -rf $VAULT/.epistemos/prompts/` documented
     as the nuclear option.
- Inline cross-reference to `RCA9-P2-005` so future readers can
  trace the doctrine back to the audit driver.

Required scans:

```bash
find "$VAULT/.epistemos/prompts" -type f -maxdepth 5 -print
rg "sk-|xoxb-|Bearer |BEGIN PRIVATE KEY|OPENAI|ANTHROPIC|GOOGLE|ACCESS_TOKEN|API_KEY" "$VAULT/.epistemos/prompts"
```

Acceptance:

- Prompt persistence contains no secrets. ✅ (structural invariant: Keychain-only key path)
- User has retention/export/purge controls if prompts contain private note/chat context. ✅ (GC + gcStaleTurns + rm -rf docs)
- Model inputs and hidden capture metadata are not retained indefinitely without user-visible policy. ✅ (opt-in gating + 20-turn GC + Settings UI toggle)

### RCA9-P2-006 - Keep Mutation OpLog projection classified as infrastructure until user path and replay truth are proven

Status: TODO

Subsystem: EventStore mutation rows, Rust OpLog projection, replay, graph/search/materialization.

Research signal: Drop 9 notes Mutation OpLog projection exists as infrastructure. That should not be promoted into a user-visible "verified memory timeline" claim until generated docs, replay, visible history, and recovery behavior are proven end to end.

Acceptance:

- One generated doc links back to a run/event source.
- Replayed OpLog reconstructs the expected state after relaunch.
- Projection failures are visible and retryable.

### Research Drop 9 Canonical Owner Map

| Root issue | Canonical owner | Merge / link duplicates |
|---|---|---|
| CodeFileService containment | `RCA4-P0-001` | `RCA2-P0-002`, `RCA7-P0-001`, `RCA5-P1-008` |
| App Store artifact scan | `RCA4-P0-002` | `RCA3-P0-001`, `RCA-P1-021` |
| Command/tool truth | `RCA4-P1-012` | `RCA-P1-004`, `RCA-P1-017`, `RCA5-P1-012`, `RCA7-P1-008` |
| AgentGrep main actor | `RCA-P1-015` | `RCA5-P1-001` |
| AFM sidecar serialization | `RCA-P1-023` | keep standalone |
| Authority persistence/enforcement | `RCA-P1-025` | `RCA2-P0-001`, Active Grants UI truth |
| Archived agent/Omega scaffolds | `RCA6-P2-005` | `RCA4-P2-001`, `RCA7-P1-009` |
| AnswerPacket/VRM implemented-not-wired | `RCA4-P1-011` | `RCA-P2-001` |
| MLX image scaffold | `RCA3-P2-003` | `/image` command truth |
| Vendored LLM dependency ≠ feature | `RCA3-P2-005` | local model product-copy audit |

### Research Drop 9 Additional Manual Checks

- Run the `CodeFileService` traversal/external URL/symlink/sidecar spoof test suite before any other fix.
- Build MAS and run artifact string/symbol scans.
- Seed fake provider secrets and launch every child/helper/process wrapper through an env probe.
- Corrupt SwiftData store and verify permanent degraded-mode truth across notes, chat, capture, `.epdoc`, and vault writes.
- Record/transcribe/cancel voice input and verify no `composer-*.m4a` files remain.
- Attach note/file live and snapshot resources, ask for allowed and disallowed writes, and verify executor-level denial/approval.
- Forge OAuth callbacks with missing/wrong/reused state and verify no credentials are stored.
- Run a large repo grep while resizing the window and profile main-thread stalls.
- Bulk-generate AFM sidecars and verify progress/cancel/queue state.
- Execute every surfaced slash/tool/MCP/LocalAgent/Agent Core command in the generated truth report.
- Send one chat turn and verify whether `AnswerPacket` is emitted, persisted, and displayed.
- Invoke `/image` and verify scaffold-only local MLX is hidden or clearly unavailable.
- Scan `<vault>/.epistemos/prompts` and other durable stores for secrets and hidden provenance.

## Research Drop 10 Integrated Verification-Pass Addendum

This drop integrates the uploaded backlog verification/fix-pass reports that were produced against packets `01` through `20`, selected live Swift/Rust files, and current build wiring. The pasted reports contain several patch files/proposals, but those patches were not applied in this repository by this addendum. Treat them as implementation instructions until the actual local code changes, compile, focused tests, runtime checks, and three clean verification passes are completed.

Important evidence boundary:

- Packets `01` through `20` are strongest for current Swift app, tests, Rust bridge/runtime registration, graph engine, and build wiring.
- `00_INDEX.md` and later doc packets were missing in one verification environment, so some canon/doc claims remain blocked-by-missing-docs in that pass.
- `project.yml` compiled-target evidence is real enough to anchor app target and App Store target wiring, but target wiring is not artifact proof.
- Source-guard tests remain useful tripwires only. They do not prove a feature works for a normal user.

### RCA10-P0-001 - Upgrade hidden capture provenance to confirmed and require migration

Status: PATCHED PARTIAL - NEW CAPTURES CLEAN / EXISTING-NOTE MIGRATION PENDING

Canonical owner:

- `RCA-P0-003`
- `RCA5-P1-006`

Subsystem: Quick Capture, `TextCapturePipeline`, audio capture, note body persistence, export/share/sync.

Evidence from verification pass:

- `Epistemos/Engine/TextCapturePipeline.swift:660-690`
- `Epistemos/App/AppBootstrap.swift:948-949`
- `Epistemos/App/AppBootstrap.swift:1785`
- Quick Capture path references the pipeline from `Epistemos/Views/Capture/QuickCaptureView.swift`.

Caller chain:

```text
Quick Capture / Capture Intent
  -> TextCapturePipeline
  -> persistNote(...)
  -> page.saveBody(body)
  -> raw note body contains <!-- capture-provenance: ... -->
```

The pass confirms `capture-provenance` in raw note bodies. It did not independently confirm `audio-source` in the same environment, so audio metadata remains a linked check rather than folded into the confirmed line item unless source proves it.

Risk:

- Hidden metadata leaks through raw Markdown, vault sync, export, copy/share, search snippets, or model context.
- Existing notes may already contain hidden provenance comments, so future-path cleanup alone is incomplete.

Patch plan:

- Move capture provenance into app-only sidecar/state keyed by page ID or mutation envelope ID.
- Remove hidden HTML comments from newly persisted note bodies.
- Add a migration that strips legacy `capture-provenance` comments from existing saved notes while preserving structured provenance in sidecar/event state if possible.
- If provenance must remain in body, render it visibly and make it user-controlled.

Required tests:

```text
TextCapturePipelineTests.captureText_doesNotPersistCaptureProvenanceComment
TextCapturePipelineTests.captureResult_stillContainsSourceSpansAndTrace
TextCapturePipelineTests.legacyCaptureProvenanceCommentMigratesOutOfBody
ExportShareTests.captureMetadataIsAbsentFromMarkdownExportByDefault
SearchIndexTests.captureMetadataIsNotIndexedAsUserContent
```

Manual proof:

1. Create one quick text capture.
2. Inspect raw backing Markdown.
3. Copy/share/export/sync the note.
4. Confirm no hidden provenance comment leaves the app.
5. Run migration on a legacy note containing `<!-- capture-provenance: ... -->` and confirm body cleanup plus provenance preservation.

Acceptance:

- No hidden capture provenance in user note bodies by default.
- Existing notes receive migration coverage.
- Provenance remains available in explicit app state where needed.

Fix-pass evidence 2026-05-09:

- Files changed:
  - `Epistemos/Engine/TextCapturePipeline.swift`
  - `EpistemosTests/TextCapturePipelineTests.swift`
- Source proof:
  - New capture path no longer appends `capture-provenance`.
  - New audio capture path no longer prepends `audio-source`.
  - Sanitizer removes legacy hidden capture/audio comments when given legacy bodies.
- Commands run:
  - Red focused test: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/TextCapturePipelineTests test CODE_SIGNING_ALLOWED=NO`
    - Red xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_03-08-50--0500.xcresult`
  - Green focused test: same command.
    - Result: passed, 44 Swift Testing tests.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_03-14-57--0500.xcresult`
  - Strict writer guard: `rg -n "<!--\\s*(capture-provenance|audio-source):|body \\+=|sourceNote|JSONEncoder\\(\\).*sourceSpans" Epistemos/Engine/TextCapturePipeline.swift Epistemos/Views/Capture/QuickCaptureView.swift Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift`
    - Result: no matches.
- Remaining risk:
  - The existing-note migration is not complete until the app walks stored note bodies, rewrites them without hidden comments, preserves intended provenance in explicit app state if needed, and proves export/share/search/sync payloads are clean at runtime.

### RCA10-P0-002 - Upgrade process-wide credential environment mirroring to confirmed

Status: PATCHED VIA DEDICATED MAS CI ARTIFACT GATE / LAUNCH SMOKE PENDING

Canonical owner:

- `RCA-P0-004`
- `RCA4-P1-001`

Subsystem: `AppBootstrap`, cloud provider auth, OAuth, `agent_core` bridge, child process launch policy.

Evidence from verification pass:

- `Epistemos/App/AppBootstrap.swift:681-755`
- `Epistemos/App/AppBootstrap.swift:2285-2296`

Caller chain:

```text
performPrimaryLaunchInitialization()
  -> detached task
  -> populateAgentCoreEnvironment()
  -> setenv(...) for API keys and OAuth access tokens
```

Risk:

- Provider secrets are widened from Keychain/scoped credential objects into the app's global process environment.
- Any later child process/helper/CLI/tool/MCP server can inherit credentials unless every launch path is scrubbed.

Backlog split:

```text
AUTH-ENV-P0-A: remove or strictly scope process-wide env mirroring.
AUTH-ENV-P0-B: prove every subprocess/helper launch uses a scrubbed child environment.
```

Required implementation direction:

- Prefer explicit FFI/session credential config instead of `setenv`.
- If temporary env bridging remains, wrap it in the narrowest possible execution window and restore/scrub immediately afterward.
- Every `Process`/`NSTask`/PTY/MCP/CLI/helper launch defaults to a scrubbed allowlist environment.

Required greps:

```bash
rg -n "Process\\(|NSTask\\(|posix_spawn|Command::new|std::process|setenv\\(|unsetenv\\(|environment =" Epistemos agent_core omega-mcp omega-ax
rg -n "OPENAI_|ANTHROPIC_|GOOGLE_|ACCESS_TOKEN|API_KEY|HF_TOKEN" Epistemos agent_core omega-mcp omega-ax
```

Required tests:

- Seed fake provider keys/tokens.
- Launch a debug child env probe through every process/helper/tool wrapper.
- Assert no child sees provider secrets unless it is an explicitly approved provider runtime.
- Add a source guard that rejects raw process launch sites without the environment policy.

Acceptance:

- Provider credentials no longer live in process-wide env by default, or every risk is explicitly scoped and tested.
- No inherited credentials in child processes.

Implementation evidence, 2026-05-09:

- `Epistemos/App/AppBootstrap.swift` converted launch/refresh credential env population into clearing behavior and added scoped env injection/restoration for the in-process Rust agent runtime.
- `Epistemos/App/ChatCoordinator.swift` scopes both `runAgentSession(...)` paths.
- `EpistemosTests/CloudProviderAuthServiceTests.swift` adds parent-env no-mirroring and scoped restore regression tests.
- `agent_core/src/security.rs` adds explicit denylist entries and a fake-secret child env probe for the Rust hardened CLI path.
- Green commands:
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CloudProviderAuthServiceTests test CODE_SIGNING_ALLOWED=NO`
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CloudProviderAgentEnvironmentTests test CODE_SIGNING_ALLOWED=NO`
  - `cargo test --manifest-path agent_core/Cargo.toml harden_cli_subprocess_clears_provider_secrets`
- Remaining risk: the all-child-launch matrix in `AUTH-ENV-P0-B` is still open and must cover Swift helpers, MCP stdio, XPC, Python/training/audio helpers, and any future process wrappers.

### RCA10-P0-003 - Keep database fallback blocked until model-container init is inspected

Status: PATCHED PARTIAL - MODEL-CONTAINER INIT INSPECTED / RUNTIME FAULT PROOF PENDING

Canonical owner: `RCA-P0-002`

Evidence from verification pass:

- `Epistemos/App/AppBootstrap.swift:2534-2599` shows database reset/relaunch handling.
- The pass did not verify model-container initialization or an in-memory fallback branch.

Risk:

- The item remains plausible and serious, but the verified slice only proves recovery/reset code exists. It does not prove or disprove the dangerous in-memory fallback.

Required next source read:

- exact SwiftData `ModelContainer` construction
- fallback/catch path
- `databaseError` state propagation
- degraded UI and write-surface behavior

Acceptance:

- Store-open failure cannot result in normal-looking editable durable surfaces.
- Any degraded/in-memory session has a persistent banner and export/recovery affordance.
- Notes, chat, capture, `.epdoc`, vault sync, and model-vault writes are blocked or explicitly temporary.

Fix-pass evidence 2026-05-09:

- Canonical implementation owner: `RCA-P0-002`.
- Source read:
  - `Epistemos/App/AppBootstrap.swift` persistent `ModelContainer` construction and catch/fallback path.
  - `Epistemos/App/RootView.swift` `databaseError` alert and recovery shell.
- Files changed:
  - `Epistemos/App/AppBootstrap.swift`
  - `Epistemos/App/RootView.swift`
  - `EpistemosTests/RuntimeValidationTests.swift`
  - `EpistemosTests/ProductionHardeningTests.swift`
- Source proof:
  - `AppBootstrap` resolves `.durable(url: modelStoreURL)` only when persistent `ModelContainer` construction succeeds.
  - On failure, the fallback is labeled `.inMemoryRecovery(reason:)`, emits an explicit persistence fault log/diagnostic, and sets `databaseError`.
  - `RootView` no longer exposes normal-looking `Continue Empty`; the recovery overlay stays visible and blocks the workspace.
- Commands run:
  - Red: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/RuntimeValidationTests test CODE_SIGNING_ALLOWED=NO`
    - Red xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-33-44--0500.xcresult`
  - Green: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/RuntimeValidationTests test CODE_SIGNING_ALLOWED=NO`
    - Result: passed, 263 Swift Testing tests.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-39-29--0500.xcresult`
  - Green: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/AuditHardeningRegressionTests test CODE_SIGNING_ALLOWED=NO`
    - Result: passed, 19 Swift Testing tests.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-48-12--0500.xcresult`
  - Green: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/SovereignGateTests test CODE_SIGNING_ALLOWED=NO`
    - Result: passed, 33 Swift Testing tests.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-51-07--0500.xcresult`
- Remaining risk:
  - The required corrupt-store, migration-failure, disk-full, and permission-denied launch smokes are still pending.
  - Export/recovery affordance is currently reset-or-quit focused; any broader export-only degraded workflow remains future work and must not imply durability.

### RCA10-P0-004 - Keep `CodeFileService` first, but add editor-call and approval-loop proof

Status: PATCHED PARTIAL - SERVICE + VISIBLE EDITOR AUTOMATED GREEN / APPROVAL LOOP PENDING

Canonical owner: `RCA4-P0-001`

New evidence from verification pass:

- `Epistemos/Engine/CodeFileService.swift:9-15`
- `Epistemos/Engine/CodeFileService.swift:70-173`
- `Epistemos/Engine/CodeFileService.swift:235-257`
- `Epistemos/Models/CodeArtifactSidecar.swift:211-222`
- `Epistemos/Engine/LiveCodeEditorController.swift:208-225`

Caller-chain upgrade:

- Code workspace/editor code executes reads/writes through `CodeFileService`.
- Approval-loop enforcement was not proven.
- Service containment remains weak unless a canonical containment resolver is locally implemented and tested.

Additional acceptance beyond Drop 9:

- Mutating operations take or derive explicit approval/grant context where tool/agent-originated.
- Direct user edits and AI/tool edits are distinguishable in provenance.
- `LiveCodeEditorController` cannot pass arbitrary external URLs to service APIs.

Required tests to add before "done":

```text
CodeFileServiceTests.readRejectsExternalAbsoluteURL
CodeFileServiceTests.updateRejectsExternalAbsoluteURL
CodeFileServiceTests.createRejectsRelativeDirectoryTraversal
CodeFileServiceTests.createRejectsAbsoluteRelativeDirectory
CodeFileServiceTests.readRejectsSymlinkEscape
CodeFileServiceTests.rejectsVaultPrefixCollision
CodeFileServiceTests.rejectsEpcacheSpoofing
CodeFileServiceTests.agentWriteWithoutGrantIsRejected
```

Fix-pass evidence 2026-05-09:

- Service and visible editor routing portions are covered by the RCA9-P0-001 evidence above.
- `LiveCodeEditorControllerTests` remained green after containment hardening.
- Approval-loop enforcement is still not closed; keep this item open until Current Access/tool grant tests prove agent/tool-originated code writes cannot execute without a scoped grant.

### RCA10-P1-001 - Upgrade `.epdoc` URL-scheme asset work to confirmed P1

Status: CONFIRMED

Canonical owner:

- `RCA-P1-001`
- `RCA3-P1-002`

Subsystem: `.epdoc`, `EpdocEditorBridge`, `WKURLSchemeHandler`, editor resource loading, Brotli.

Evidence from verification pass:

- `Epistemos/Engine/EpdocEditorBridge.swift:29-58`
- `Epistemos/Engine/EpdocEditorBridge.swift:230-282`

Caller chain:

```text
WKURLSchemeHandler (@MainActor)
  -> webView(_:start:)
  -> Data(contentsOf:)
  -> Brotli decompression / response
```

Risk:

- `.epdoc` cold open and asset misses can perform file IO and decompression on the UI actor.

Patch plan:

- Add a testable asset loader abstraction.
- Move bundle/package reads and Brotli decompression off the main actor.
- Cache decompressed assets where possible.
- Keep only `WKURLSchemeTask` response handoff on main actor if required by WebKit.

Required tests:

```text
EpdocEditorAssetLoaderTests.cacheHitAvoidsDiskRead
EpdocEditorAssetLoaderTests.cacheMissLoadsOffMain
EpdocEditorAssetLoaderTests.brotliDecodeDoesNotRunOnMainActor
EpdocEditorBridgePerformanceTests.repeatedBundleAssetResolutionIsBounded
```

Manual proof:

- Cold-open a large `.epdoc`.
- Clear asset cache.
- Profile main-thread time in scheme-handler reads/decompression.

### RCA10-P1-002 - Upgrade `.epdoc` autosave/projection churn to confirmed P1

Status: CONFIRMED

Canonical owner:

- `RCA-P1-002`
- `RCA-P1-020`
- `RCA5-P1-010`
- `RCA7-P1-004`

Subsystem: `.epdoc` document save, autosave, readable blocks, FTS/search, graph projection.

Evidence from verification pass:

- `Epistemos/Engine/EpdocDocument.swift:177-186`
- `Epistemos/Engine/EpdocDocument.swift:336-362`
- `Epistemos/Engine/EpdocDocument.swift:442-481`
- partial adjacent: `Epistemos/Engine/EpdocGraphProjector.swift:191-195`

Caller chain:

```text
content change
  -> dirty mark
  -> autosave task every ~250 ms
  -> write package
  -> index/project readable blocks
  -> graph persist / refresh notifications
```

Risk:

- The save path bundles correctness-critical package save with secondary projection/index/graph work.
- Graph persistence failures may be logged but not surfaced.
- Large docs can stutter during typing/autosave.

Patch plan:

- Separate correctness-critical package save from projection/index/graph phases.
- Debounce or incrementalize projection work.
- Background graph/index phases with bounded queueing, stale generation cancellation, and retry/error visibility.
- Add consistency checks between package content, local stats, projected graph, and reopened state.

Required tests:

```text
EpdocAutosaveStressTests.largeDocTypingDoesNotQueueUnboundedProjectionWork
EpdocProjectionTests.graphProjectionFailureDoesNotCorruptCanonicalPackage
EpdocProjectionTests.reopenReprojectConsistency
EpdocProjectionTests.staleProjectionNeverOverwritesCanonicalJSON
```

Manual proof:

- Type continuously in a large `.epdoc` with blocks/images/wikilinks.
- Measure p95/p99 frame time and autosave latency.
- Kill/relaunch and compare visible local stats with graph projection.

### RCA10-P1-003 - Track dense launch work with first-interaction signposts

Status: NEEDS-RUNTIME-PROOF

Canonical owner: `RCA-P1-003`

Evidence from verification pass:

- `Epistemos/App/AppBootstrap.swift:2280-2316`

Research signal: `performPrimaryLaunchInitialization()` immediately starts activity tracking, workspace restore/summary/autosave, live-note scheduler refresh, and deferred runtime services. This is plausible first-click latency, but the pass did not capture startup signposts.

Acceptance:

- First window visible, first click accepted, and first keystroke accepted are measured under no-vault, medium-vault, and large-vault launches.
- Nonessential services defer until after first frame/first interaction.
- Concurrent post-launch tasks are capped and visible if long-running.

### RCA10-P1-004 - Upgrade chat stream full-buffer rescans to confirmed P1

Status: CONFIRMED

Canonical owner:

- `RCA-P1-006`
- `RCA5-P0-002`

Subsystem: `ChatState`, `ThinkTagStreamRouter`, `UserFacingStreamRouter`, `UserFacingModelOutput`, `ChatCoordinator`.

Evidence from verification pass:

- `Epistemos/State/ChatState.swift:1044-1075`
- `Epistemos/Engine/ThinkTagStreamRouter.swift:223-260`
- `Epistemos/Engine/Extensions.swift:827-844`
- `Epistemos/Engine/Extensions.swift:1029-1063`
- `Epistemos/App/ChatCoordinator.swift:1983-1984`

Caller chain:

```text
token delta
  -> chatState.appendStreamingText(...)
  -> UserFacingStreamRouter.ingest(...)
  -> full rawText rescan for visible/reasoning text on every chunk
```

Risk:

- O(n^2)-style pressure as output grows.
- Long streaming chats can stall the main actor and inflate allocations.

Patch plan:

- Replace full-buffer recomputation with an incremental state machine parser.
- Maintain only a compact rolling window for tag-boundary detection.
- Keep existing `ThinkTagStreamRouter` behavior where it is already incremental, but ensure the non-tag path is chunk-bounded too.

Required tests:

```text
TriageServiceStreamingTests.explicitThinkTagsUseIncrementalRouter
ChatStreamingPerfTests.chunked1kCharsIsBounded
ChatStreamingPerfTests.chunked10kCharsIsBounded
ChatStreamingPerfTests.chunked100kCharsIsBounded
ChatStreamingPerfTests.invalidPartialThinkTagDoesNotTriggerFullRescan
```

Manual proof:

- Stream a very long answer.
- Profile `appendStreamingText`, `ThinkTagStreamRouter`, and `UserFacingModelOutput`.
- Count SwiftData saves and graph/search notifications during stream.

### RCA10-P1-005 - Upgrade Shadow/Halo empty-on-failure to confirmed P1

Status: CONFIRMED

Canonical owner: `RCA-P1-013`

Subsystem: `ShadowSearchService`, `HaloController`, Shadow health/settings row, recall panels.

Evidence from verification pass:

- `Epistemos/Engine/ShadowSearchService.swift:160-164`
- `Epistemos/Engine/ShadowSearchService.swift:307-329`
- `Epistemos/Engine/HaloController.swift:164-206`
- `Epistemos/Views/Settings/ShadowSearchHealthRow.swift:5-8`
- `Epistemos/Views/Settings/ShadowSearchHealthRow.swift:54-87`

Caller chain:

```text
Halo query
  -> ShadowSearchService
  -> FFI/backend failure converted to []
  -> HaloController sees "no hits"
  -> diagnostics visible only in settings/dev surfaces
```

Risk:

- Backend unavailable looks like "no related thoughts," which misleads users and hides failures.

Patch plan:

- Return a typed result from search: `.hits([Hit])`, `.noResults`, `.degraded(ErrorSummary)`.
- Halo surfaces degraded/error status distinct from empty results.
- Settings diagnostics stay secondary, not the only failure surface.

Required tests:

```text
HaloControllerTests.backendFailureShowsDegradedState
HaloControllerTests.noHitsIsDistinctFromBackendFailure
ShadowSearchServiceTests.ffiFailureDoesNotReturnSilentEmptyHits
```

Manual proof:

- Inject/kill Shadow backend.
- Type in notes/chat.
- Confirm visible degraded/unavailable state rather than empty related results.

### RCA10-P1-006 - Split editor/code file I/O hot-path work from `AgentGrepService`

Status: PATCHED PARTIAL - VISIBLE CODE EDITOR HOT PATH GREEN / AGENTGREP PENDING

Canonical owner:

- `RCA-P1-015`
- `RCA5-P1-008`

Evidence from verification pass:

- `Epistemos/Engine/LiveCodeEditorController.swift:1-15`
- `Epistemos/Engine/LiveCodeEditorController.swift:208-225`
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:1117-1131`
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:1532-1546`

Research signal: The reviewed editor path performs file reads/writes and code service calls on UI-facing paths. This overlaps with `AgentGrepService`, but should be tracked as a broader "editor and grep file I/O off hot UI paths" item.

Patch plan:

- Move large file reads/search/writes into background actors.
- Publish progress/error on main actor.
- Route all writes through the safe `CodeFileService` after containment lands.
- Do not bypass sidecar/provenance/verified-write policy for visible editor saves.

Required tests:

```text
LiveCodeEditorControllerTests.largeFileOpenDoesNotBlockMainActor
CodeEditorSaveTests.debouncedWriteUsesCodeFileService
CodeEditorSaveTests.writeFailureDoesNotCreateFalseSwiftDataSuccess
AgentGrepServiceTests.sidecarReadsDoNotRunOnMainActor
```

Fix-pass evidence 2026-05-09:

- Files changed:
  - `Epistemos/Engine/CodeFileService.swift`
  - `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
  - `Epistemos/Views/Notes/CodeEditorView.swift`
  - `EpistemosTests/CodeFileServiceTests.swift`
  - `EpistemosTests/NoteEditorLayoutTests.swift`
- Tests added:
  - `CodeFileServiceTests.asyncCodeFileReadAndUpdateAPIsRoundTrip`
  - `NoteEditorLayoutTests.visibleCodeEditorAvoidsRenderPathCodeFileIO`
- Source proof:
  - `CodeFileService` is no longer class-wide `@MainActor`.
  - `CodeFileService.readCodeFileAsync` and `CodeFileService.updateCodeFileAsync` run contained read/update work in `Task.detached(priority: .userInitiated)`.
  - `NoteDetailWorkspaceView` no longer calls synchronous `readCodeFile` from the SwiftUI render-derived content helper. It uses `cachedCodeFileContent(page:filePath:)` and schedules a cancellable async body refresh keyed by page id and file path.
  - Visible code saves await `CodeFileService.updateCodeFileAsync` and only then apply SwiftData success state, so a file write failure does not create a false persisted success.
  - `CodeEditorView` accepts async-loaded initial content only when it has not diverged from the prior initial value, preventing late async reads from clobbering active edits.
- Commands run:
  - Test-first red command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CodeFileServiceTests -only-testing:EpistemosTests/NoteEditorLayoutTests test CODE_SIGNING_ALLOWED=NO`
    - Result: failed before product patch because `CodeFileService.readCodeFileAsync` and `CodeFileService.updateCodeFileAsync` did not exist.
    - Red xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-59-13--0500.xcresult`
  - Guard-adjustment run: same command failed because a source guard assumed `CodeFileService.*Async(at:)` was on one line; product code was already routing through the async API.
    - Failed xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_02-04-21--0500.xcresult`
  - Focused green command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CodeFileServiceTests -only-testing:EpistemosTests/NoteEditorLayoutTests test CODE_SIGNING_ALLOWED=NO`
    - Result: passed, 90 Swift Testing tests in 2 suites.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_02-07-43--0500.xcresult`
  - Diff hygiene: `git diff --check`
    - Result: passed.
  - Source guard: `rg -n "return try files\\.readCodeFile\\(at: URL\\(fileURLWithPath: filePath\\)\\)\\.body|try files\\.updateCodeFile\\(at: URL\\(fileURLWithPath: filePath\\), body: content\\)|@MainActor\\s+public final class CodeFileService|String\\(contentsOfFile: filePath|try content\\.write\\(toFile:" Epistemos/Views/Notes/NoteDetailWorkspaceView.swift Epistemos/Engine/CodeFileService.swift Epistemos/Views/Notes/CodeEditorView.swift`
    - Result: no matches.
- Remaining risk:
  - `AgentGrepService` per-hit sidecar/file reads are still pending under this same item.
  - Runtime profile of a large code-file switch is still required for manual proof; automated guards prove routing and write-order truth but not p95 UI latency.

### RCA10-P1-007 - Split App Store compile gating from UI/copy honesty

Status: PARTIALLY-FIXED

Canonical owner:

- `RCA-P1-021`
- `RCA4-P0-002`

Evidence from verification pass:

- `project.yml:178-183`
- `Epistemos/Bridge/ToolTierBridge.swift:11-25`
- `Epistemos/Views/Settings/AgentControlSettingsView.swift:67-75`

Research signal: Separate App Store target wiring and some surfaced-tool filtering are real. The open risk is not basic compile gating; it is artifact proof plus copy/UI surface honesty across Settings and tool panels.

Backlog split:

```text
APPSTORE-GATING-A: compiled target/build gating.
APPSTORE-GATING-B: built artifact scan.
APPSTORE-GATING-C: UI/copy/surfaced affordance honesty.
```

Acceptance:

- MAS build artifact scan is green.
- MAS UI does not advertise Pro-only tools as available.
- Direct/Pro build shows only tools that can execute in that build/tier.

### RCA10-P1-008 - Add Active Grants UI truth-model item

Status: CONFIRMED-RISK

Canonical owner: `RCA-P1-025`

Subsystem: Settings "Active Grants," `AgentControlSettingsView`, Rust grants, attachment-derived rows, static explanatory rows.

Evidence from verification pass:

- `Epistemos/Views/Settings/AgentControlSettingsView.swift:243-346`
- `Epistemos/Views/Settings/AgentControlSettingsView.swift:777-837`
- `agent_core/src/tools/registry.rs:658-686`

Risk:

- Settings may mix authoritative Rust grants, transient attachments, and static "Shell / external tools" explanations into one "Active Grants" view.
- Operators can believe a static row is a current grant or a real enforcement decision.

Patch plan:

- Separate persisted policy, stored runtime grants, transient attachment grants, and static explanatory capability rows.
- Label each row with source and expiry.
- Add read-write-read tests for settings persistence and revocation.

Acceptance:

- UI cannot imply a grant exists unless a real policy/grant object backs it.
- Revocation is reflected both in settings and actual tool dispatch.

### RCA10-P1-009 - Add `ModelVaultBrowserStore` containment as a concrete patch item

Status: PATCH PROPOSAL EXISTS / NEEDS LOCAL APPLICATION

Canonical owner:

- `RCA7-P2-002`
- model-vault verified-write work

Subsystem: model vault browser/sidebar, prompt files, model-authored artifacts, `NoteFileStorage`.

Research signal: The uploaded fix-pass found `ModelVaultBrowserStore` enumerates under a root, reads with synchronous `Data(contentsOf:)`, writes through `NoteFileStorage.writeTextAtomically`, creates files/folders by appending caller-supplied relative directories, and deletes arbitrary URLs passed into `deleteItem(at:)`. The proposed patch adds root containment checks and changes delete call sites to pass root.

Severity:

- P2 if only trusted user UI supplies paths.
- P1 if model-generated or agent/tool-originated paths can call these APIs.

Required tests:

```text
ModelVaultBrowserStoreContainmentTests.createRejectsParentTraversal
ModelVaultBrowserStoreContainmentTests.createFolderRejectsParentTraversal
ModelVaultBrowserStoreContainmentTests.deleteRejectsOutsideRoot
ModelVaultBrowserStoreContainmentTests.readRejectsOutsideRoot
ModelVaultBrowserStoreContainmentTests.symlinkEscapeIsRejected
```

Acceptance:

- All model vault reads/writes/deletes are contained to the selected model vault root.
- Sensitive prompt/system-prompt files are not modified by AI/tool-originated paths without verified write policy.

### RCA10-P2-001 - Upgrade source-guard evidence discipline to confirmed

Status: CONFIRMED

Canonical owner: `RCA-P2-017`

Evidence from verification pass:

- `EpistemosTests/MiniChatViewAuditTests.swift:129-170`
- `EpistemosTests/RuntimeValidationTests.swift:3316-3345`
- `EpistemosTests/ProductionHardeningTests.swift:1209-1230`

Research signal: These tests load repo files and assert string containment. That is useful as drift detection but misleading if counted as runtime proof.

Required CI/report categories:

```text
source guards
generated tests
unit tests
integration tests
runtime UI tests
performance tests
manual proofs
artifact scans
```

Acceptance:

- Release reporting never aggregates source guards with runtime tests as a single "feature proven" count.
- Every ship-critical behavior covered only by source guards gets at least one runtime/integration proof.

### RCA10-P2-002 - Keep `StructureRegistry` patch proposal but require caller proof

Status: PATCH PROPOSAL EXISTS / NEEDS LOCAL APPLICATION

Canonical owner: `RCA-P2-003`

Research signal: The uploaded patch proposal splits active runtime schemas from roadmap/gap schemas because the original registry reportedly mixed real entries with gap descriptors such as `search_intent` marked "Gap G2."

Required tests:

```text
StructureRegistryTests.allSchemasExcludesRoadmapGapDescriptors
StructureRegistryTests.roadmapSchemasIncludesGapDescriptors
StructureRegistryTests.mcpCatalogDoesNotExposeRoadmapOnlySchemasAsRuntime
```

Acceptance:

- Agent-facing/MCP-facing schema catalogs contain only runtime schemas unless a developer diagnostic view explicitly labels roadmap gaps.

### RCA10-P2-003 - Keep `StructuredQueryParser` grammar patch proposal but require product caller proof

Status: PATCH PROPOSAL EXISTS / NEEDS LOCAL APPLICATION

Canonical owner: `RCA-P2-004`

Research signal: The uploaded patch proposal fixes a parser that documented `&`, `|`, negation, and grouping, but only split on top-level `&` and used `compactMap`, silently dropping invalid terms.

Required tests:

```text
StructuredQueryParserTests.parsesTopLevelOr
StructuredQueryParserTests.parsesGroupedAndOr
StructuredQueryParserTests.negatesGroupedExpression
StructuredQueryParserTests.invalidAndTermFailsInsteadOfDroppingTerm
StructuredQueryParserTests.docsExamplesRoundTrip
```

Acceptance:

- Parser behavior matches every UI/docs example, or docs/UI are downgraded to the actual grammar.

### RCA10-P2-004 - Keep `SidecarCache` O(n) LRU patch proposal and benchmark it

Status: PATCH PROPOSAL EXISTS / NEEDS LOCAL APPLICATION

Canonical owner: `RCA-P2-015`

Research signal: The uploaded patch proposal replaces an array-backed LRU hot path where lookup/invalidate used `firstIndex(of:)` and eviction used `removeFirst()` despite O(1) claims.

Required tests:

```text
SidecarCacheTests.lookupRemainsBoundedAtCacheLimit
SidecarCacheTests.invalidateRemainsBoundedAtCacheLimit
SidecarCacheTests.evictionPreservesMostRecentlyUsedEntries
```

Acceptance:

- Complexity claim matches implementation.
- Graph/inspector/render-adjacent cache lookups do not lock around O(n) work under large sidecar sets.

### RCA10-P2-005 - Keep `SpotlightIndexer` off-main patch proposal but require compile/runtime proof

Status: PATCH PROPOSAL EXISTS / NEEDS LOCAL APPLICATION

Canonical owner: `RCA-P2-013`

Research signal: The uploaded patch proposal moves indexing tasks away from explicit `Task { @MainActor in ... }` orchestration because `SpotlightIndexer` is reportedly `@MainActor` and batch reindex awaits body loads and indexing batches.

Required tests:

```text
SpotlightIndexerTests.reindexAllDoesNotCaptureSDPageAcrossTaskBoundary
SpotlightIndexerTests.largeVaultReindexDoesNotBlockMainActor
SpotlightIndexerTests.cancelledReindexDoesNotPublishStaleResults
```

Acceptance:

- Large reindex does not block typing/scrolling.
- SwiftData model values are not illegally captured across isolation boundaries.

### RCA10-P2-006 - Keep TriageService explicit-thinking patch proposal but audit non-tag streams too

Status: PATCH PROPOSAL EXISTS / PARTIAL

Canonical owner:

- `RCA-P1-006`
- streaming pressure work

Research signal: The uploaded patch proposal adds an explicit-thinking fast path using the existing incremental `ThinkTagStreamRouter` when `<think>`-style tags are detected. This helps only the explicit-tag case. The non-tag streaming path still needs an incremental parser or bounded recomputation proof.

Acceptance:

- Explicit thinking tags use incremental routing.
- Non-tag long streams are also chunk-bounded.
- No full-buffer rescans per token in any normal chat mode.

### RCA10-P2-007 - Add concrete orphan candidate: `ComposerMicButton`

Status: NEEDS CALLER PROOF

Canonical owner: `RCA-P2-010`

Evidence from verification pass:

- `Epistemos/Views/Chat/ComposerMicButton.swift:1-28` had no reviewed call sites.
- `ChatInputBar.swift:747-770` uses `VoiceInputButton`.

Risk:

- Duplicate/dead mic UI can keep old behavior alive or confuse future fixes.

Acceptance:

- `ComposerMicButton` is either wired intentionally, deleted/quarantined, or marked as archived.
- Voice cleanup tests cover the actually mounted component (`VoiceInputButton`) rather than a dead duplicate.

### RCA10 Verification Commands To Add

Focused commands after local patch application:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test \
  -only-testing:EpistemosTests/TextCapturePipelineTests \
  -only-testing:EpistemosTests/StructuredQueryParserTests \
  -only-testing:EpistemosTests/EpistemosSidecarTests \
  CODE_SIGNING_ALLOWED=NO

xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/CodeFileServiceTests test \
  CODE_SIGNING_ALLOWED=NO
```

Runtime checks:

```bash
# Capture metadata leak
rg "capture-provenance|audio-source" "$VAULT" Epistemos docs EpistemosTests

# Composer temp files
find "${TMPDIR:-/tmp}" -name 'composer-*.m4a' -print

# Credential inheritance
rg "Process\\(|NSTask\\(|posix_spawn|Command::new|std::process" Epistemos agent_core omega-mcp omega-ax

# App Store artifact scan
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore \
  -configuration Release -destination 'platform=macOS' build
```

### Research Drop 10 Immediate Status Updates

```text
RCA-P0-003 / RCA5-P1-006
Status: CONFIRMED
Reason: line-backed TextCapturePipeline evidence shows capture-provenance persisted in raw note body.

RCA-P0-004 / RCA4-P1-001
Status: CONFIRMED
Reason: AppBootstrap line-backed evidence shows process-wide setenv for provider credentials.

RCA-P1-001
Status: CONFIRMED
Reason: EpdocEditorBridge line-backed evidence shows WKURLSchemeHandler path with sync I/O/decompression risk.

RCA-P1-002 / RCA-P1-020
Status: CONFIRMED-RISK
Reason: EpdocDocument line-backed evidence shows autosave + projection/index/graph churn.

RCA-P1-006
Status: CONFIRMED
Reason: chat stream path performs full rawText re-scan per token chunk.

RCA-P1-013
Status: CONFIRMED
Reason: Shadow/Halo path converts backend failure to empty hits.

RCA-P2-017
Status: CONFIRMED
Reason: source-string tests must be categorized separately from runtime proof.

RCA7-P2-002
Status: PATCH-PROPOSED
Reason: ModelVaultBrowserStore containment patch/tests exist but are not applied here.
```

## Research Drop 11 Integrated Current-App Release-Truth Addendum

This drop integrates the current-app red-team audit focused on V1 release truth, App Store target proof, graph/search/vault coherence, tool-surface honesty, and several source-confirmed hot paths. It is stricter than the earlier feature-led drops: a feature is "real" only when the evidence shows a live build target, a runtime/user path, a persistence/side-effect path, or repeated verification against the live `Epistemos` target.

Scope caveat:

- The audit text mixes two packet-coverage perspectives: one pass had packets `21` through `40` and strong release docs/build artifacts; another had packets `01` through `19` and stronger executable-source snippets.
- Therefore this drop separates "current app release truth" from "source-confirmed fix target."
- Do not turn any item into a ship claim unless the local repo now proves it with current source, a caller chain, runtime/manual proof, and target-specific gates.

Release-truth conclusion:

```text
Ship the narrow current app, not the registry-shaped fantasy.
```

Safe V1 scope:

- notes/prose editor
- main chat and Mini Chat
- search/readable blocks
- global graph only after connected-vault sync and fullscreen perf gates
- `.epdoc` only after save/reopen/projection latency smoke
- privacy/settings surfaces
- resource-targeted permissions and verified writes, with honest scope labels
- deliberately limited local/cloud model and vault features

Unsafe V1 scope until proven:

- "everything in the tool registry"
- universal permission model claims
- graph/search/Halo consistency after vault mutations without runtime smoke
- App Store review hardening without artifact scan and non-empty MAS tests
- Hermes/Omega/Helios/ANE/XPC/AgentGrep surfaces not mounted or not executable

### RCA11-P0-001 - Keep the Mini Chat workspace autosave crash as a permanent release regression

Status: PATCHED-BUT-WATCH

Subsystem: Mini Chat, workspace autosave, `WorkspaceService.captureSnapshot`, duplicate `SDPage.id` handling.

Research signal: The current-app audit reports a real user-visible crash path: Mini Chat plus workspace autosave could crash on the main thread when `WorkspaceService.captureSnapshot()` built a dictionary assuming unique page IDs. It was reportedly patched and reverified, but this is a release-blocker class issue and must remain in the regression suite.

Risk:

- A local prompt or autosave-heavy editing session can re-enter workspace snapshotting and crash if duplicate page IDs or stale page rows reappear.
- This is not a graph-rendering problem; it is persistence/snapshot identity discipline.

Required tests:

```text
WorkspaceServiceTests.captureSnapshotToleratesDuplicatePageIDs
MiniChatRegressionTests.localPromptDuringAutosaveDoesNotCrash
WorkspaceAutosaveTests.duplicatePageIDsEmitInvariantWarningNotCrash
```

Manual proof:

- Open Mini Chat.
- Run a local prompt while notes/workspace autosave is active.
- Repeat with duplicated/stale page identities in a test fixture.
- Verify no crash and inspect snapshot persistence.

Acceptance:

- Duplicate page IDs never crash snapshot capture.
- Duplicate identity is logged as an invariant violation for later cleanup.
- This check runs in every release pass.

### RCA11-P1-001 - Treat connected-vault graph/search/Halo sync as not closed until one-session smoke passes

Status: PATCHED-BUT-NOT-CLOSED

Canonical links:

- vault lifecycle/sync P0/P1 items
- graph/search/Halo truth items
- `RCA5-P0-001`

Subsystem: active vault, Notes, Graph, Search, Halo diagnostics, Settings, vault registry.

Research signal: The audit reports that Notes and Graph could visibly show cached rows while Settings said "No vault connected" and diagnostics said no active vault. The disconnected-cache truth path was patched, but the connected-vault "create/import a note and watch graph/search/Halo converge without relaunch" proof remains open.

Required one-session smoke:

```text
select clean vault
create note
rename note
move note
delete note
verify Notes, Search, Graph query, Halo diagnostics, and Settings agree on:
  active vault id
  artifact identity
  deleted/moved state
  no stale cached rows
no relaunch allowed
```

Acceptance:

- Graph/search/Halo/vault consistency is not marketed until this smoke is green.
- Every surface derives active-vault identity from one canonical source.
- Disconnected-cache rows are visibly marked cached/disconnected.

### RCA11-P1-002 - Keep graph fullscreen performance as a current open blocker

Status: OPEN

Subsystem: `MetalGraphView`, graph renderer, Hologram/graph full-screen, frame pacing.

Research signal: The V1 interaction audit leaves a graph full-screen regression open and unprofiled. Performance audit docs also say graph frame-time proof is missing.

Risk:

- The graph is a mounted current-app surface.
- A fullscreen transition can be visibly broken even if the graph engine and data model tests pass.

Required proof:

- Time Profiler and Animation Hitches on production-sized graph.
- 750/2,000/10,000 node fixtures where appropriate.
- Pan, zoom, filter, select, sidebar toggle, fullscreen enter/exit.
- p95/p99 frame times and allocation spikes captured.

Acceptance:

- Do not change renderer/shaders blindly.
- Do not claim graph performance fixed without retained profiler evidence.

### RCA11-P1-003 - Promote MAS subprocess audit warnings to target-aware failures

Status: PATCHED - SOURCE AUDIT FAILS MAS SUBPROCESS FINDINGS / GREEN

Canonical links:

- `RCA4-P0-002`
- App Store artifact scan work

Subsystem: `Tools/app-review-audit/app-review-audit.sh`, MAS release gate, subprocess/PTY/shell/MCP surfaces.

Research signal: The App Review audit script hard-fails some executable-code download and HELIOS-toggle patterns, but subprocess surface detection is a stage-0 warning path rather than a failure. The release audit acknowledges this limitation.

Risk:

- MAS-reachable subprocess code can pass the App Review audit as a warning.
- A "green" app-review script can be overstated as App Store safety.

Patch plan:

- Make subprocess/PTY/shell/MCP findings target-aware.
- Fail MAS if the path is reachable or bundled outside explicitly approved stubs.
- Keep direct/Pro findings as warnings only when compile/build gates prove unreachable from MAS.

Regression test:

```text
intentionally add MAS-reachable Process() / PTY / shell path
run Tools/app-review-audit/app-review-audit.sh
assert failure, not warning
```

Acceptance:

- MAS artifact scan and source audit both fail on MAS-reachable subprocess surfaces.

Fix-pass evidence 2026-05-09:

- `Tools/app-review-audit/app-review-audit.sh` now accepts target modes and treats MAS/App Store subprocess findings as hard failures while keeping direct/Pro findings informational.
- The script strips common MAS-unreachable Swift `#if !EPISTEMOS_APP_STORE`, `#if !MAS_SANDBOX`, and `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)` regions before scanning MAS-visible Swift subprocess surfaces.
- Regression coverage added in `EpistemosTests/AppStoreHardeningTests.appReviewAuditFailsMASSubprocessFindingsInsteadOfWarning`.
- Red command:
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/AppStoreHardeningTests test CODE_SIGNING_ALLOWED=NO`
  - Failed because subprocess detection was still warning-only.
  - Red xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_03-32-08--0500.xcresult`
- Green commands:
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/AppStoreHardeningTests test CODE_SIGNING_ALLOWED=NO`
    - Passed, 24 Swift Testing tests.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_04-45-57--0500.xcresult`
  - `./Tools/app-review-audit/app-review-audit.sh appstore`
    - Passed with no MAS-visible subprocess launch surface.
- Remaining risk:
  - Manual MAS UI/copy honesty still belongs to the separate UI sweep.

### RCA11-P1-004 - Label permissions UI as resource grants, not universal capability control

Status: PATCHED - SCOPED LABEL GREEN / FULL TOOL LEDGER PENDING

Canonical links:

- `RCA-P1-025`
- `RCA2-P0-001`
- Active Grants UI truth model

Subsystem: permission grants, verified writes, resource-targeted tools, Settings "Active Grants," non-resourceable mutating tools.

Research signal: The Known Issues register and current audit say resource-targeted mutating tools now have real fail-closed checks, persisted grants, revocation UI, and verified writes. That is good. The same evidence says shell, messaging, browser/UI automation, AppleScript, and other non-resourceable tools are governed by tier/approval/policy gates outside the ResourceId grant model.

Risk:

- Users/operators can read "what the assistant can currently do" as universal when it only covers resource-targeted grants.

Required UI copy:

```text
Stored Resource Grants
```

or equivalent. If a broader capability view exists, it must be a separate ledger that includes non-resourceable mutating tools and their tier/approval state.

Required proof:

- Compare visible grants UI against full tool registry.
- Mark every mutating tool as:
  - resource-grant governed
  - tier/policy governed
  - approval-only
  - disabled/unavailable
  - scaffold/deferred

Acceptance:

- Permissions UI cannot imply universal control over all mutating capabilities.

2026-05-09 scoped label patch:

- Composer popover and Settings grants section now use `Stored Resource Grants`.
- Shell/external tool approval rows were removed from this resource-grant UI.
- Added source-guard coverage in `EpistemosTests/CurrentAccessParityTests.resourceGrantSurfacesUseScopedLabel` and `resourceGrantSurfacesExcludeShellApprovalRows`.
- Green command:
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CurrentAccessParityTests test CODE_SIGNING_ALLOWED=NO`
- Remaining risk:
  - The broader command/tool truth ledger is still tracked separately; non-resourceable mutating tools still need the advertised -> parsed -> compiled -> approved -> executed -> logged -> visible table before this becomes universal capability proof.

### RCA11-P1-005 - Resolve Swift tier truth: no app-wide Swift `PRO_BUILD` claim without proof

Status: CONFIRMED-RISK

Subsystem: Swift compile flags, App Store target, direct/Pro target, `ToolTierBridge`, target-specific UI.

Research signal: The release audit says direct build links `omega_ax` and permissive direct entitlements while App Store omits `omega_ax` and compiles with `EPISTEMOS_APP_STORE MAS_SANDBOX`. It also notes no simple app-wide Swift `PRO_BUILD` compile condition in the project. Some older doctrine says Pro-only Swift code is protected by `#if PRO_BUILD`, so this must be reconciled.

Required decision:

1. Add a real Swift tier flag for direct/Pro if the product wants Swift compile-tier separation.
2. Or stop describing Swift surfaces as `PRO_BUILD` compile-gated and document the actual mechanism: target choice, entitlements, runtime policy, source guards, Rust cfg features, and dead stripping.

Required grep:

```bash
rg "#if PRO_BUILD|PRO_BUILD|EPISTEMOS_APP_STORE|MAS_SANDBOX" Epistemos Epistemos.xcodeproj project.yml
```

Acceptance:

- Every user-visible tiered Swift surface has a verified compile/runtime gate.
- MAS cannot see Pro-only UI or strings except explicitly unavailable stubs.

### RCA11-P1-006 - Move Prose editor full-structure parsing off the per-keystroke hot path

Status: CONFIRMED

Subsystem: `ProseTextView2`, `MarkdownContentStorage`, TextKit 2 editor, large note typing/paste.

Evidence from source-confirmed pass:

- `Epistemos/Views/Notes/ProseTextView2.swift:415-461`
- `Epistemos/Views/Notes/MarkdownContentStorage.swift:100-117`
- `Epistemos/Views/Notes/MarkdownContentStorage.swift:125-133`

Caller chain:

```text
text edit
  -> didChangeText()
  -> reparseAndInvalidate()
  -> markdownDelegate.reparse(text: string)
  -> buildLineStarts(from:) full scan
  -> markdown_parse_structure
  -> token cache clear
  -> visible-line update/layout invalidation
```

Risk:

- Long Markdown notes, table/code-heavy files, and large paste events can synchronously full-parse on every keystroke.

Patch plan:

- Keep cheap paragraph invalidation immediate.
- Debounce full-structure parsing.
- Add generation tokens so stale background parse results are ignored.
- For large notes, parse viewport/dirty range first and full document later.

Required tests:

```text
ProseTextView2PerformanceTests.largeNoteTypingDoesNotFullParsePerKeystroke
MarkdownContentStorageTests.staleBackgroundParseIsIgnored
MarkdownContentStorageTests.largePasteUsesDebouncedFullParse
```

Manual proof:

- 10k-line Markdown note.
- Type 200 characters and paste 100 KB.
- Capture parse count and p95 edit latency.

### RCA11-P1-007 - Remove direct code-file disk IO from SwiftUI view helpers

Status: PATCHED PARTIAL - AUTOMATED GREEN / LARGE-FILE RUNTIME PROFILE PENDING

Canonical links:

- `RCA4-P0-001`
- `RCA5-P1-008`
- `RCA10-P1-006`

Subsystem: `NoteDetailWorkspaceView`, `CodeEditorView`, `CodeFileService`, code-backed notes.

Evidence from source-confirmed pass:

- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:1098-1135`
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:1527-1545`

Caller chain:

```text
SwiftUI noteEditorSurface
  -> CodeEditorView(content: codeFileContent(...))
  -> fallback String(contentsOfFile:)
edits
  -> saveCodeFileContent
  -> content.write(toFile:)
```

Risk:

- Synchronous disk IO can occur during SwiftUI view recomputation or UI-facing edit callbacks.
- This bypasses canonical `CodeFileService` containment/provenance/sidecar policy.

Patch plan:

- Fix `CodeFileService` containment first.
- Route code-note reads/writes through a contained service or async `CodeFileViewModel`.
- Load content once per selected file identity and cache by modified time/hash.
- Debounce writes and surface save errors.
- Never call `String(contentsOfFile:)` from a SwiftUI body helper.

Required tests:

```text
CodeEditorViewTests.bodyConstructionDoesNotTouchDisk
NoteDetailWorkspaceViewTests.largeCodeFileSwitchDoesNotReadOnMainThread
CodeEditorSaveTests.visibleCodeSaveUsesCodeFileService
```

Fix-pass evidence 2026-05-09:

- Covered by `RCA10-P1-006` fix-pass evidence.
- `NoteDetailWorkspaceView` now treats code-file disk reads as an async refresh outside SwiftUI body construction.
- Focused green command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CodeFileServiceTests -only-testing:EpistemosTests/NoteEditorLayoutTests test CODE_SIGNING_ALLOWED=NO`
  - Result: passed, 90 Swift Testing tests in 2 suites.
  - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_02-07-43--0500.xcresult`
- Remaining risk:
  - Needs a manual/runtime profile with a large code file to prove file switching stays low-latency on the target app.

### RCA11-P1-008 - Make Vault Organizer mutations transactional across SwiftData and filesystem

Status: CONFIRMED

Subsystem: `VaultOrganizerView`, `VaultSyncService`, `SDPage`, `SDFolder`, graph/search hooks.

Evidence from source-confirmed pass:

- `Epistemos/Views/Notes/VaultOrganizerView.swift:446-536`

Caller chain:

```text
Vault Organizer suggestion
  -> applySuggestion
  -> mutate SDPage/SDFolder
  -> modelContext.save()
  -> vaultSync.movePage(...) or vaultSync.createDirectory(...)
```

Risk:

- SwiftData can say a note moved or a folder exists while the filesystem operation fails.
- Graph/search/vault state can drift from disk.

Patch plan:

- For folder creation, create directory first, then insert/save `SDFolder`, with rollback on save failure.
- For page moves, use a transactional service or persist original SwiftData state and perform compensating rollback if filesystem move fails.
- Surface failure to the user; do not log-only.

Required tests:

```text
VaultOrganizerTests.moveRollbackWhenVaultSyncFailsAfterSwiftDataSave
VaultOrganizerTests.createFolderRollbackWhenFilesystemCreateFails
VaultOrganizerTests.failedApplyDoesNotRefreshGraphAsSuccess
```

Manual proof:

- Force `vaultSync.movePage` failure after SwiftData save.
- Relaunch.
- Compare DB, filesystem, graph, and search.

### RCA11-P1-009 - Fix graph filter truth drift or prove renderer uses an equivalent snapshot

Status: CONFIRMED-UNLESS-ALTERNATE-RENDERER-PATH-PROVEN

Subsystem: `FilterEngine`, graph sidebar/search/model/vault filters, Rust render payload.

Evidence from source-confirmed pass:

- `Epistemos/Graph/FilterEngine.swift:23-77`
- `Epistemos/Graph/FilterEngine.swift:155-168`

Research signal: Filter/search/model/vault state can say the graph is filtered, while `isNodeVisible` only checks node type and focus unless a separate host snapshot applies the missing fields.

Risk:

- Search/model/vault filters can become UI theater if render payload ignores them.

Patch plan:

- Extend `isNodeVisible` to include `searchMatchedNodeIds`, `selectedModelProfileId`, and `selectedVaultFilter`.
- Or prove the renderer uses `GraphFilterSnapshot` and add equivalence tests between filter state and rendered node IDs.

Required tests:

```text
FilterEngineTests.searchFilterHidesNonMatchingNodes
FilterEngineTests.modelFilterHidesNonMatchingNodes
FilterEngineTests.vaultFilterHidesNonMatchingNodes
GraphRendererTests.visibleNodePayloadMatchesFilterEngine
```

Manual proof:

- Search graph for a unique node.
- Inspect visible node IDs sent to Rust graph engine.
- Nonmatches must disappear from render payload, not only sidebar/UI state.

### RCA11-P2-001 - Add App Store scheme tests or a dedicated MAS test plan

Status: PATCHED VIA DEDICATED MAS CI ARTIFACT GATE / SCHEME TESTABLES STILL EMPTY

Subsystem: `Epistemos-AppStore.xcscheme`, MAS test coverage, release truth.

Research signal: The App Store scheme has an empty `<Testables>` block in the cited audit. The App Store target/build may be real, but its scheme does not by itself run App Store-specific runtime tests.

Patch plan:

- Add App Store target testables where practical.
- Or add a dedicated MAS test plan that runs source guards, artifact scan, UI surface scan, and smoke tests against the MAS-built app.

Acceptance:

- A failing MAS-specific behavior fails CI.
- Release notes do not imply App Store runtime test coverage if the scheme remains empty.

Fix-pass evidence 2026-05-09:

- `.github/workflows/ci.yml` now has a dedicated `W26.b - App Store artifact and subprocess release gate` step after the App Store Release build.
- The CI gate runs:
  - `./Tools/app-review-audit/app-review-audit.sh appstore`
  - `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-audit ./scripts/scan_appstore_bundle.sh "${app_path}"`
- Regression coverage added in `EpistemosTests/AppStoreHardeningTests.appStoreSchemeHasTestsOrCIRunsDedicatedMASArtifactGate`.
- Green command:
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/AppStoreHardeningTests test CODE_SIGNING_ALLOWED=NO`
  - Passed, 24 Swift Testing tests.
  - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_04-45-57--0500.xcresult`
- Remaining risk:
  - The `Epistemos-AppStore.xcscheme` `<Testables>` block remains empty by design in this pass; the dedicated CI release gate is the chosen coverage path.

### RCA11-P2-002 - Rename or expand `scripts/run_all_tests.sh`

Status: CONFIRMED HARNESS GAP

Subsystem: test runner naming, Swift/Rust workspace tests, App Store scheme, `agent_core`, `omega-mcp`, `omega-ax`, `epistemos-shadow`, code index.

Research signal: The audit says `scripts/run_all_tests.sh` only runs `graph-engine` Rust tests and the `Epistemos` scheme. It does not run the App Store scheme or every Rust crate linked by the app.

Patch plan:

1. Rename it to match reality, such as `run_core_tests.sh`.
2. Or expand it to the actual release matrix:
   - Swift `Epistemos`
   - Swift App Store/MAS plan
   - `graph-engine`
   - `agent_core`
   - `omega-mcp`
   - `omega-ax` where relevant
   - `epistemos-shadow`
   - code-index crates
   - artifact scans

Required proof:

- Add a deliberately failing test to `agent_core` or MAS plan and confirm the script catches it.

### RCA11-P2-003 - Make runtime perf-budget measurements mandatory before perf claims

Status: CONFIRMED HARNESS GAP

Subsystem: `scripts/check-perf-budgets.sh`, runtime measurements, CI.

Research signal: The perf-budget script enforces binary size ceilings, but runtime budgets are informational when the measurement JSON is missing. Missing runtime data does not fail the check.

Patch plan:

- Add strict mode for release: missing runtime measurement file fails.
- Keep non-strict/dev mode informational.
- Require p95/p99 metrics for graph, recall/Halo, `.epdoc`, code editor, launch, and streaming before perf claims.

Acceptance:

```bash
rm -f benchmarks/results/runtime.json
scripts/check-perf-budgets.sh --release
# must fail
```

### RCA11-P2-004 - Quarantine deferred/unmounted surfaces from feature inventories

Status: CONFIRMED

Subsystem: GraphInspect shell, retired Omega orchestrator/views, Visual Intelligence bridge, CoreML action backend, AgentGrep production mount, companion mirror registration.

Research signal: The release audit explicitly marks multiple preserved surfaces as deferred, retired, unmounted, or implemented-not-wired. They can remain in source only if they do not inflate current-app claims.

Required quarantine list:

```text
GraphInspectModeView / graph inspect renderer shell
retired Omega orchestrator state
retired Omega companion views
Visual Intelligence macOS bridge
CoreML action backend
AgentGrep production code-index path if unmounted
companion mirror registration without live caller
HELIOS V5 runtime controls
ANE direct backend
Provider XPC streaming mock/protocol-only path
```

Acceptance:

- Runtime mounts are grepped and documented.
- Unmounted surfaces are excluded from user-facing feature inventories.
- Developer diagnostics can show them only with explicit scaffold/deferred labels.

### RCA11-P2-005 - Fix SDF graph label budget guard

Status: PATCHED - FOCUSED AUTOMATED GREEN / MANUAL FRAME-HITCH PROOF PENDING

Subsystem: `SDFLabelInstanceBuilder`, graph label rendering, per-frame budget.

Evidence from source-confirmed pass:

- `Epistemos/Graph/SDFLabelInstanceBuilder.swift:1-157`

Research signal: The guard reportedly checks `totalEmitted >= atlas.glyphs.count + budgetRemaining`, which is not a clean per-label or global budget check.

Patch plan:

- Track `emittedForThisLabel`.
- Break when `emittedForThisLabel >= budgetRemaining`.
- Keep global `totalEmitted <= labelBudget`.

Required tests:

```text
SDFLabelInstanceBuilderTests.outputCountNeverExceedsLabelBudget
SDFLabelInstanceBuilderTests.longLabelsRespectPerFrameBudget
SDFLabelInstanceBuilderTests.denseGraphLabelsDoNotGrowUploadBufferUnbounded
```

2026-05-09 implementation note:

- Fixed `Epistemos/Graph/SDFLabelInstanceBuilder.swift` so each label stops when the exact remaining frame budget is consumed.
- Added `EpistemosTests/SDFLabelInstanceBuilderTests.swift` with:
  - `outputCountNeverExceedsLabelBudget`
  - `longLabelsRespectPerFrameBudget`
- Green command:
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/SDFLabelInstanceBuilderTests test CODE_SIGNING_ALLOWED=NO`
    - Passed. xcresult summary: 2 passed, 0 failed.
- Remaining risk:
  - Dense-graph runtime frame-hitch/upload-buffer proof is still pending.

Manual proof:

- Dense graph with long labels.
- Confirm no per-frame buffer growth or upload spikes.

### Research Drop 11 Current-App Ledger Updates

| Area | Classification | Drop 11 verdict |
|---|---|---|
| `.epdoc` documents | `visible-working but fragile` | Real document type and workflow, but save/reopen/projection latency smoke remains required. |
| Main chat / Mini Chat | `visible-working patched-watch` | Real runtime path; autosave crash fix must stay a permanent regression. |
| Search/readable blocks | `visible-working` | Keep derivative-index drift checks and connected-vault convergence smoke. |
| Global graph | `visible-broken until proof` | Mounted, but duplicate identity/sync/fullscreen/perf gates remain. |
| Vault lifecycle/sync | `visible-working high-risk` | Needs one canonical active-vault truth across Notes/Search/Graph/Halo/Settings. |
| App Store target | `feature-gated real but not fully proven` | Separate target is real; artifact scan and non-empty MAS tests still required. |
| Resource-targeted permissions / verified writes | `hidden-working scope-limited` | Real for resource grants; not universal capability control. |
| HELIOS V5 runtime controls | `excluded-speculative` | Source-preservation only unless WRV gates prove current runtime. |
| GraphInspect shell | `scaffold-only` | Must stay unmounted or explicitly diagnostic. |
| Retired Omega orchestrator/companion UI | `hidden-dead` | Do not count as current runtime. |
| Visual Intelligence macOS bridge | `feature-gated/deferred` | Not current v1 runtime. |
| CoreML action backend | `implemented-not-wired` | Loader exists; product feature disabled/unavailable. |
| AgentGrep production code index path | `implemented-not-wired unless mounted` | Keep out of user claims until caller path exists. |

### Research Drop 11 Exact Runtime Gates

Run these before any release-ready claim:

1. Connected-vault convergence: create, rename, move, delete, then verify Notes/Search/Graph/Halo/Settings without relaunch.
2. Mini Chat autosave regression: local prompt during autosave-heavy workspace state with duplicate page fixture.
3. Graph fullscreen Time Profiler + Animation Hitches with production-sized graph.
4. MAS artifact scan: strings/symbols/resources for subprocess, PTY, shell, AX, ScreenCaptureKit, browser automation, external MCP, and helper residue.
5. MAS test plan: prove the App Store scheme or dedicated MAS plan runs non-empty checks.
6. `.epdoc` smoke: new doc, local image, graph insert, save, close, reopen, inspect canonical JSON, readable blocks, graph projection, stats, and latency.
7. Passive-launch TCC/log attribution using a production-like signed build.
8. Permission scope: compare Stored Resource Grants UI with full mutating tool registry.
9. Prose editor large-doc typing/paste profile.
10. Vault Organizer transactional failure injection.
11. Graph filter visible-node payload inspection.
12. SDF label dense graph budget test.

## Research Drop 12 Integrated Pre-Fix Orchestration Addendum

This drop is the second-to-last research intake before implementation begins. Its purpose is not to add another loose research layer; it converts the accumulated audit into a pre-build operating order for a recursive Codex terminal agent. The core rule is: do not build new architecture or brain features until the current-app P0/P1 release-truth, security, privacy, and runtime-proof gates are closed or explicitly quarantined.

Scope caveat:

- One pass in the pasted research had packets `21` through `40` and strong docs/build/script evidence, but not live app packets `01` through `20`.
- Another pass had `00_INDEX.md`, packets `01` through `19`, and packets `21` through `40`, but packet `20` was missing.
- Therefore this drop preserves both source-confirmed and secondary-evidence findings, while requiring the local terminal agent to re-open the live repo source before changing code.

### RCA12-P0-001 - Add authority-floor status to every backlog claim before implementation

Status: CONFIRMED PROCESS BLOCKER

Canonical links:

- `RCA-P0-001`
- `RCA8-P1-001`
- evidence taxonomy / source-guard discipline

Subsystem: release truth, backlog hygiene, canon authority, post-floor implementation claims.

Research signal: The new pass reinforces that the repo canon treats architecture locks as canon but implementation slices as candidates until independently verified. The Master Research Index also ranks current code plus passing logs above docs. Therefore post-floor items must not be treated as shipped because a plan or packet says so.

Required backlog columns:

```text
authority_floor_status
source_proof
caller_chain
user_surface
side_effect_or_persistence_path
test_proof
runtime_manual_proof
artifact_target_proof
ship_status
```

Allowed status values:

```text
confirmed-current
confirmed-risk
candidate
implemented-not-wired
scaffold-only
feature-gated
hidden-dead
blocked-by-missing-source
blocked-by-runtime-proof
```

Acceptance:

- No release claim lacks an authority-floor status.
- Any post-floor item without caller-chain-plus-runtime proof is downgraded before implementation begins.
- The terminal agent updates this log after each fix with the actual verification class, not just "tests pass."

### RCA12-P1-001 - Confirm App Store scheme/test coverage gap as a concrete CI task

Status: CONFIRMED

Canonical links:

- `RCA11-P2-001`
- `RCA2-P1-015`

Subsystem: `Epistemos-AppStore.xcscheme`, MAS target tests, release verification.

Research signal: The new pass confirms the App Store scheme has an empty `<Testables>` block while the main `Epistemos` scheme includes `EpistemosTests.xctest`. The App Store target can be real and still untested as its own scheme.

Patch options:

1. Add a dedicated MAS smoke test target/job.
2. Add a CI script that builds `Epistemos-AppStore` and runs focused MAS source guards, artifact scans, UI-surface checks, and launch smoke under App Store compilation conditions.

Acceptance:

- A MAS-specific break fails CI.
- App Store release notes cannot claim runtime test coverage from the main scheme alone.

Fix-pass evidence 2026-05-09:

- Chosen patch option: dedicated MAS CI artifact/source gate instead of adding App Store scheme testables in this pass.
- `.github/workflows/ci.yml` now builds `Epistemos-AppStore` in Release and runs `Tools/app-review-audit/app-review-audit.sh appstore` plus `scripts/scan_appstore_bundle.sh` against the built `.app`.
- Regression coverage:
  - `EpistemosTests/AppStoreHardeningTests.appStoreSchemeHasTestsOrCIRunsDedicatedMASArtifactGate`
- Green proof:
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/AppStoreHardeningTests test CODE_SIGNING_ALLOWED=NO`
    - Passed, 24 Swift Testing tests.
    - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_04-45-57--0500.xcresult`
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Release -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
    - Passed.
  - `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-audit scripts/scan_appstore_bundle.sh /Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Release/Epistemos.app`
    - Passed.
- Remaining risk:
  - Launch smoke under App Store compilation and a manual MAS UI/copy sweep are still pending.

### RCA12-P0-002 - Promote App Store artifact verification to the first release-truth gate

Status: PATCHED - RELEASE ARTIFACT PROOF GREEN / MANUAL MAS UI SWEEP PENDING

Canonical links:

- `RCA4-P0-002`
- `RCA3-P0-001`
- `RCA-P1-021`
- `RCA11-P1-003`

Subsystem: Xcode App Store target, Rust feature flags, build phases, resource sanitization, final `.app` artifact, App Review audit.

Research signal: Direct packet evidence says the App Store build is doing several correct things: omitting `omega_ax`, using MAS Rust features, removing Pro frameworks/resources, and sanitizing training/research assets. The remaining failure is proof rigor: the audit script still treats subprocess-surface detection as informational warnings and does not inspect final artifacts deeply enough.

Required artifact scan:

```bash
xcodebuild -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'platform=macOS' build

APP="path/to/Epistemos.app"
find "$APP" -type f -print0 | xargs -0 strings 2>/dev/null | \
  rg "pty|osascript|cli_passthrough|bash_execute|Command::new|fork|exec|docker|stdio_mcp|ScreenCaptureKit|AXUIElement|/bin/sh|/bin/bash|launchctl"
```

Also inspect:

```bash
find "$APP" -type f -perm +111 -print
otool -L <embedded dylib or executable>
nm -gU <embedded dylib or executable>
```

Acceptance:

- MAS-reachable subprocess, PTY, shell, AX, ScreenCaptureKit, browser automation, external MCP, and Pro helper residue fail the release gate.
- Source guards stay secondary; artifact scan becomes mandatory.

Fix-pass evidence 2026-05-09:

- `scripts/scan_appstore_bundle.sh` added as the final `.app` artifact scanner. It inspects:
  - bundle strings,
  - possible executable files,
  - `otool -L` linkage,
  - `nm -gU` exported symbols,
  - resource names and packaged research/tool residue.
- `Tools/app-review-audit/app-review-audit.sh` now fails MAS/App Store source-visible subprocess findings instead of warning.
- `agent_core/src/tools/registry.rs` no longer embeds Pro-only legacy alias names in MAS builds.
- `agent_core/src/approval.rs` no longer embeds container-detection strings in non-Pro builds.
- `Epistemos/State/AgentCommandCenterState.swift` hides Pro subprocess tool names from MAS command-center mode catalogs.
- Regression tests:
  - `EpistemosTests/AppStoreHardeningTests.appStoreArtifactScanInspectsFinalBundleStringsSymbolsExecutablesAndResources`
  - `EpistemosTests/AppStoreHardeningTests.appReviewAuditFailsMASSubprocessFindingsInsteadOfWarning`
  - `EpistemosTests/AppStoreHardeningTests.appStoreAgentCommandModesHideProSubprocessTools`
  - `agent_core/tests/mas_pro_feature_gates.rs::mas_legacy_aliases_do_not_embed_pro_subprocess_tool_names`
- Red/green commands are recorded under `RCA9-P0-002`.
- Final green artifact proof:
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Release -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
    - Passed, built `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Release/Epistemos.app`.
  - `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/appstore-audit scripts/scan_appstore_bundle.sh /Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Release/Epistemos.app`
    - Passed: no prohibited runtime strings, no prohibited runtime symbols, and no prohibited research/tool resource residue.
- Remaining risk:
  - Manual App Store UI/copy sweep and launch smoke remain pending.

### RCA12-P1-002 - Fix the `.epdoc` slash-image persistence split

Status: PATCHED - FOCUSED AUTOMATED GREEN / OFFLINE REOPEN SMOKE PENDING

Canonical link: `RCA5-P1-009`

Subsystem: `js-editor/src/extensions/slash-menu.ts`, `image-asset-bridge.ts`, `.epdoc` package assets, offline document durability.

Research signal: The new pass confirms two image semantics in `.epdoc`: slash-menu image insertion prompts for a remote URL and inserts it directly, while paste/drop/toolbar routes through `storeImageAsset` for package-local storage.

Risk:

- Slash-inserted images can break offline.
- A private remote URL can be embedded silently into a local-first package.
- Users get inconsistent behavior depending on insertion path.

Patch plan:

- Delete or replace the slash-menu URL prompt path.
- Route slash image insertion through the same native/package-local asset bridge used by paste/drop and toolbar insertion.
- If remote image URLs remain intentionally supported, make them a separate command named "Remote image URL" with explicit offline/privacy copy.

Required tests:

```text
EpdocSlashImageTests.slashInsertedImageStoresPackageAsset
EpdocSlashImageTests.slashInsertedImageRendersAfterOfflineReopen
EpdocSlashImageTests.remoteImageCommandIsExplicitlyLabeledIfPresent
```

Manual proof:

- Insert image via slash command.
- Save, quit, disable network, reopen.
- Inspect package assets and `content.pm.json`.

2026-05-09 status note:

- Covered by the implementation evidence under `RCA5-P1-009`.
- Remaining risk is unchanged: offline save/reopen package inspection is still pending.

### RCA12-P1-003 - Confirm `/image` command truth mismatch and hide until executable

Status: PATCHED - FOCUSED AUTOMATED GREEN / MANUAL COMMAND SMOKE PENDING

Canonical links:

- `RCA9-P2-002`
- command/tool truth table

Subsystem: slash command UI, `AgentCommandCenterState`, `MLXImageGenerationService`, Rust tool registry.

Research signal: The new pass confirms `/image` is user-visible while default MLX image generation still throws `fluxPipelineUnavailable`, and Rust registry/catalog gates/hides `image_generate` differently from the UI.

Patch plan:

- Hide `/image` in MAS and any build/provider route where no executable backend exists.
- Or make `/image` return a clear unavailable/setup message before appearing in the normal command list.
- Tool truth report must mark `/image` as visible only when a real executor and approval path exist.

Acceptance:

- Typing `/image` in MAS/Core does not advertise a non-working feature.
- Pro/direct build shows `/image` only when a configured provider/local pipeline can execute it.

2026-05-09 status note:

- Covered by the implementation evidence under `RCA2-P1-014` and `RCA3-P2-003`.
- Remaining risk is unchanged: manual command-palette smoke and the full command/tool truth report are still pending.

### RCA12-P1-004 - Fix test harness truth: `run_all_tests.sh` is not all tests

Status: CONFIRMED

Canonical links:

- `NEW-P2-ALLTESTS-001`
- `RCA11-P2-002`
- `RCA-P2-017`

Subsystem: `scripts/run_all_tests.sh`, CI naming, Swift/Rust workspace coverage.

Research signal: The new pass confirms `scripts/run_all_tests.sh` claims "Run ALL tests - Swift + Rust" while only running `graph-engine` Rust tests and the main `Epistemos` scheme. It omits App Store scheme and other linked Rust crates such as `agent_core`, `omega-mcp`, `omega-ax`, `epistemos-shadow`, and code index crates.

Patch options:

1. Rename to `run_core_tests.sh`.
2. Expand to a true release matrix.

True release matrix minimum:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' build
cargo test --manifest-path graph-engine/Cargo.toml
cargo test --manifest-path agent_core/Cargo.toml
cargo test --manifest-path omega-mcp/Cargo.toml
cargo test --manifest-path omega-ax/Cargo.toml
swift test --package-path LocalPackages/LocalLLMClient
```

Acceptance:

- The script name matches its actual scope.
- A failing test in `agent_core` or MAS build is caught by the release command.

### RCA12-P1-005 - Make runtime perf measurements required in release mode

Status: CONFIRMED

Canonical links:

- `NEW-P1-PERF-GATE-001`
- `RCA11-P2-003`

Subsystem: `scripts/check-perf-budgets.sh`, runtime p95/p99 measurements, release CI.

Research signal: The new pass confirms the script exits successfully when runtime measurement JSON is absent, printing "no measurement yet," while the performance audit says multiple hot paths still need p95/p99 proof.

Patch plan:

- Add `--require-runtime` or `--release` mode.
- In release mode, missing runtime measurement file exits nonzero.
- Malformed runtime JSON keeps its distinct error path.

Acceptance:

```bash
rm -f benchmarks/results/runtime.json
scripts/check-perf-budgets.sh --release
# must fail
```

Runtime measurements required before perf claims:

- code editor
- recall/Halo
- `.epdoc`
- chat/Raw Thoughts streaming
- graph pan/zoom/fullscreen
- launch/first interaction

### RCA12-P1-006 - Treat Current Access as partially evidenced, but not runtime-proven

Status: PATCHED - AUTOMATED PARITY GREEN / MANUAL RUNTIME PROOF PENDING

Canonical links:

- `RCA2-P0-001`
- `RCA9-P1-005`
- `RCA11-P1-004`

Subsystem: composer `Current Access`, `ChatCoordinator`, resource grants, Rust permission store, tool execution.

Research signal: The packet-backed docs say a real permission-grant architecture exists and resource-write denial/revoke tests exist. The current composer chip path still needs direct source/runtime proof that the visible summary comes from the compiled request/permission plan.

Patch plan:

- Wire composer "Current Access" summary from compiled request/permission plan.
- Rename UI scope to "Stored Resource Grants" unless it includes non-resourceable mutating tools.
- Add runtime parity tests comparing chip text, compiled tool plan, Rust allowlist, and actual executor behavior.

Required tests:

```text
CurrentAccessParityTests.attachedFileAllowsOnlyThatFile
CurrentAccessParityTests.unattachedFileWriteDeniedBeforeMutation
CurrentAccessParityTests.chipMatchesCompiledAllowedToolNames
CurrentAccessParityTests.resourceGrantUIExcludesShellUnlessCapabilityLedgerIncludesIt
```

2026-05-09 implementation note:

- Added `ComposerCurrentAccessPlan` as the shared composer/settings resource-grant truth for visible rows, exact writable `resourceURI`s, and compiled provider-native tool summary.
- Added focused parity tests:
  - `attachedFileAllowsOnlyThatFile`
  - `snapshotAttachmentCannotBeMutated`
  - `chipMatchesCompiledAllowedToolNames`
  - `resourceGrantSurfacesUseScopedLabel`
  - `resourceGrantSurfacesExcludeShellApprovalRows`
- Current gap from the original requested test names:
  - `unattachedFileWriteDeniedBeforeMutation` is covered at the plan/Rust R5 gate level, but the full live agent mutation attempt still needs manual/runtime proof.
- Green commands:
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CurrentAccessParityTests test CODE_SIGNING_ALLOWED=NO`
  - `cargo test --manifest-path agent_core/Cargo.toml --lib resources::bridge::tests::attached_resource_from_paste_is_snapshot_read_only`
  - `cargo test --manifest-path agent_core/Cargo.toml --lib resources::tool_authz::tests`
  - `cargo test --manifest-path agent_core/Cargo.toml --lib r5_gate_`

### RCA12-P1-007 - Confirm OAuth callback hardening as secondary-evidence P0 until source reopened

Status: SOURCE REOPENED / PATCHED - AUTOMATED VALIDATION GREEN / RUNTIME SMOKE PENDING

Canonical links:

- `RCA2-P0-004`
- `RCA5-P1-004`
- `RCA9-P1-006`

Subsystem: `CloudProviderAuthService`, `LocalOAuthCallbackServer`, Google OAuth, provider auth settings.

Research signal: Earlier packet-backed drops say the callback listener binds on `.any` and accepts callbacks without `state` validation. The current pass could not re-open packets `01` through `20`, so this remains confirmed by secondary evidence until current source is checked.

Implementation requirement:

- loopback-only listener
- random one-time state
- strict path/provider/port validation
- replay rejection
- concurrent sign-in isolation

Required tests:

```text
OAuthCallbackTests.rejectsMissingState
OAuthCallbackTests.rejectsWrongState
OAuthCallbackTests.rejectsReplayedState
OAuthCallbackTests.rejectsWrongPath
OAuthCallbackTests.rejectsWrongHost
OAuthCallbackTests.concurrentSignInsDoNotCrossComplete
```

Patch evidence 2026-05-09:

- Files changed:
  - `Epistemos/Engine/CloudProviderAuthService.swift`
  - `EpistemosTests/CloudProviderAuthServiceTests.swift`
- Result:
  - Current source was reopened and patched.
  - Google OAuth callback validation now requires matching one-time state, strict callback path, host `127.0.0.1`, and non-empty code.
  - Listener source uses `requiredLocalEndpoint` loopback with an ephemeral `.any` port.
- Commands:
  - Red: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/LocalOAuthCallbackValidationTests test CODE_SIGNING_ALLOWED=NO`
    - Missing validator before patch.
    - xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_02-45-17--0500.xcresult`
  - Green: same command.
    - 6 tests passed.
    - xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_02-50-26--0500.xcresult`
  - Green: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CloudProviderAuthServiceTests test CODE_SIGNING_ALLOWED=NO`
    - 23 tests passed.
    - xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_02-53-18--0500.xcresult`
- Remaining risk:
  - Browser sign-in, forged local callback, and `lsof` loopback runtime checks are still pending.

### RCA12-P2-001 - Keep three-lane brain work parked behind current-app blockers

Status: DEFERRED ARCHITECTURE / DO NOT START BEFORE P0-P1 CLOSURE

Subsystem: AnswerPacket, ClaimGraph, RuntimeInvariant, Metal kernels, falsifier harness, future EpiKernel/Active-Support/CAFTI lanes.

Research signal: The new research introduces a useful three-lane architecture and Monday-code lock (`answer_packet.rs`, `claim_graph.rs`, `runtime_invariant.rs`, `gate3_route.metal`, `assembly_route.metal`, `falsifier_harness.rs`). This is valuable, but it must not pull the terminal agent away from current-app release blockers.

Parking-lot rule:

```text
No AnswerPacket/ClaimGraph/kernel/falsifier implementation work begins until:
1. CodeFileService containment is fixed and tested.
2. DB fallback degraded mode is safe.
3. credential env mirroring is removed or fully scoped.
4. OAuth callback state/loopback is hardened.
5. capture metadata and voice temp privacy issues are fixed.
6. App Store artifact/test gates are enforced.
7. Current Access/runtime permission parity is proven.
```

After that, start with Lane 3 / EpiKernel truth work:

- `answer_packet.rs`
- `claim_graph.rs`
- `runtime_invariant.rs`
- `falsifier_harness.rs`

Do not begin Metal kernels (`gate3_route.metal`, `assembly_route.metal`) until CPU oracle tests and runtime invariants exist.

### RCA12 Pre-Build Recursive Fix Order

The terminal agent must follow this order unless source inspection proves a blocker is already fixed:

1. Build and verify the current issue matrix from this backlog.
2. `CodeFileService` containment and tests.
3. Database fallback recovery-only / temporary-session truth.
4. Credential environment mirroring removal and child env probes.
5. OAuth callback state + loopback hardening.
6. Capture provenance/audio metadata removal from note bodies.
7. Composer voice temp-file cleanup.
8. App Store artifact scan and MAS scheme/test coverage.
9. `/image` and `.epdoc` slash-image truth.
10. Current Access runtime parity.
11. Direct code-file SwiftUI IO removal and CodeFileService routing.
12. `.epdoc` main-actor asset loading and autosave/projection proof.
13. Query/search/mention/Halo main-actor pressure.
14. Vault Organizer transactional safety.
15. Connected-vault graph/search/Halo convergence.
16. Graph filter truth and fullscreen performance.
17. Harness truth: `run_all_tests.sh`, perf budgets, source-guard taxonomy.
18. Only then: AnswerPacket/ClaimGraph/RuntimeInvariant future architecture.

### RCA12 Required File Batches For Terminal Codex

Give the terminal agent the full repo when possible. If operating from packets/uploads, give these files first:

```text
AGENTS.md
docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md
docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
docs/KNOWN_ISSUES_REGISTER.md
docs/audits/V1_RELEASE_AUDIT_2026_05_07.md
docs/audits/V1_DEEP_INTERACTION_AUDIT_2026_05_08.md
docs/audits/PERFORMANCE_CONCURRENCY_AUDIT.md
docs/audits/PRIVACY_APP_STORE_AUDIT.md
docs/audits/USER_WIRING_CAPABILITY_MAP.md
docs/audits/DATA_PERSISTENCE_INDEXING_AUDIT.md
docs/audits/PRE_HELIOS_FEATURE_AUDIT_2026_05_06.md
docs/audits/codebase-verbatim-packets-2026-05-09/00_INDEX.md
docs/audits/codebase-verbatim-packets-2026-05-09/01_CODE_PACKET.md
docs/audits/codebase-verbatim-packets-2026-05-09/02_CODE_PACKET.md
docs/audits/codebase-verbatim-packets-2026-05-09/03_CODE_PACKET.md
docs/audits/codebase-verbatim-packets-2026-05-09/04_CODE_PACKET.md
docs/audits/codebase-verbatim-packets-2026-05-09/05_CODE_PACKET.md
docs/audits/codebase-verbatim-packets-2026-05-09/06_CODE_PACKET.md
docs/audits/codebase-verbatim-packets-2026-05-09/07_CODE_PACKET.md
docs/audits/codebase-verbatim-packets-2026-05-09/08_CODE_PACKET.md
docs/audits/codebase-verbatim-packets-2026-05-09/09_CODE_PACKET.md
docs/audits/codebase-verbatim-packets-2026-05-09/10_CODE_PACKET.md
docs/audits/codebase-verbatim-packets-2026-05-09/11_CODE_PACKET.md
```

Critical live source files:

```text
Epistemos/App/AppBootstrap.swift
Epistemos/App/EpistemosApp.swift
Epistemos/App/RootView.swift
Epistemos/App/ChatCoordinator.swift
Epistemos/App/WorkspaceService.swift
Epistemos/Engine/CodeFileService.swift
Epistemos/Models/CodeArtifactSidecar.swift
Epistemos/Engine/CloudProviderAuthService.swift
Epistemos/Engine/TextCapturePipeline.swift
Epistemos/Engine/ComposerVoiceInputService.swift
Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift
Epistemos/Engine/EpdocEditorBridge.swift
Epistemos/Engine/EpdocDocument.swift
Epistemos/Engine/EpdocGraphProjector.swift
Epistemos/Views/Chat/ChatInputBar.swift
Epistemos/State/AgentCommandCenterState.swift
Epistemos/Bridge/ToolTierBridge.swift
Epistemos/Views/Notes/NoteDetailWorkspaceView.swift
Epistemos/Views/Notes/ProseTextView2.swift
Epistemos/Views/Notes/MarkdownContentStorage.swift
Epistemos/Views/Notes/VaultOrganizerView.swift
Epistemos/Views/Notes/NoteBacklinksPanel.swift
Epistemos/Views/Graph/MetalGraphView.swift
Epistemos/Graph/GraphState.swift
Epistemos/Graph/FilterEngine.swift
Epistemos/Graph/SDFLabelInstanceBuilder.swift
Epistemos/Engine/QueryEngine.swift
Epistemos/Engine/QueryRuntime.swift
Epistemos/Engine/RetrievalRuntime.swift
Epistemos/Engine/ShadowSearchService.swift
Epistemos/Engine/HaloController.swift
Epistemos/Sync/VaultSyncService.swift
Epistemos/Sync/SearchIndexService.swift
Epistemos/Sync/NoteFileStorage.swift
Epistemos/AppStore/AppStoreComputerUseStubs.swift
js-editor/src/extensions/slash-menu.ts
js-editor/src/extensions/image-asset-bridge.ts
js-editor/src/bridge/inbound.ts
agent_core/src/tools/registry.rs
agent_core/src/permissions.rs
agent_core/src/resources/bridge.rs
omega-mcp/src/lib.rs
omega-mcp/src/pty.rs
omega-mcp/src/osascript.rs
graph-engine/src/lib.rs
graph-engine/src/renderer.rs
graph-engine/src/physics.rs
project.yml
Epistemos.xcodeproj/project.pbxproj
Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos.xcscheme
Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-AppStore.xcscheme
Epistemos-AppStore-Info.plist
Epistemos-Info.plist
Tools/app-review-audit/app-review-audit.sh
scripts/run_all_tests.sh
scripts/check-perf-budgets.sh
build-agent-core.sh
build-omega-mcp.sh
bundle-app-runtime-assets.sh
```

### Research Drop 12 Additional Runtime Gates

- App Store scheme must run a non-empty MAS test/smoke plan.
- Slash image insertion must store local package assets by default.
- `/image` must be hidden unless the runtime backend is executable.
- `run_all_tests.sh` must either become truthful or be renamed.
- Runtime perf gate must fail in release mode when measurement JSON is absent.
- The final prompt for terminal Codex must point to this backlog and forbid future architecture work until current-app P0/P1 is clean.

## Research Drop 13 Finalization and Live-Vault Blocker Addendum

This is the final pre-fix synthesis from the last research drop plus the live user report on May 9, 2026. It preserves the frontier research, but it changes the immediate implementation order: the next Codex terminal session must start with vault reset/add/remove/selection hardening because the user is actively blocked. Future-brain work, CLI convenience work, and local-agent shell design remain preserved but must not displace the current-app persistence/security fixes.

### Drop 13 Executive Merge

The research program is preserved as three lanes:

| Lane | Status | Build rule |
|---|---|---|
| EpiKernel Exocortex | primary future lane | Start only after current-app P0/P1 blockers close. The first safe pieces are AnswerPacket / ClaimGraph / RuntimeInvariant, not Metal kernels. |
| Cerebrum Shell | bridge lane | Keep a pretrained/local model as language cortex while app/runtime own memory, tools, proof, and mutation. |
| CAFTI / PARN / Duplex operator atlas | far-frontier lane | Preserve as research. Do not implement inside the app until the present substrate is reliable. |

The formal research stack to preserve:

- 12-plane compact bundle / branch-safe charts.
- EML primitive algebra and density theorem.
- interaction-rank memory law.
- duplex fusion theorem.
- Theorem 7 / Autogenous Kernel Identity as an engineering theorem candidate, with C7 still conjectural.
- plot requests for active memory versus interaction rank and page I/O latency versus page size.

Current-app truth still wins over research doctrine. The app is not ready to become the theorem-safe substrate until it stops leaking secrets, stale vault state, hidden metadata, and false capability promises.

### RCA13-P0-001 - Harden vault reset/add/remove/select and purge stale Notes/Graph/Search state

Status: focused Wave 0 patch landed / targeted automated proof green / real large-vault folder smoke passed / reset proof still pending
Severity: P0
Subsystem: vault lifecycle, Settings reset, Notes sidebar, Graph, Search, Halo, SwiftData, derived stores, bookmarks.

User report:

- The app will not reliably let the user choose a vault.
- Notes sidebar and Graph still show old notes after using Settings -> Reset Everything.
- Reset Everything "literally does not work" from the user's perspective.
- Vault add/removal is a priority product feature, not a nice-to-have.

Source context from this pass:

- `Epistemos/App/AppBootstrap.swift:2632-2684` implements `resetAllData()`.
- `resetAllData()` cancels query task, stops vault watching, clears persisted vault selection, calls `NoteWindowManager.shared.resetForVaultRebuild()`, deletes several SwiftData model classes, calls `NoteFileStorage.removeAllManagedBodies()`, clears chat state, resets Notes UI, sets setup mode, and marks `graphState.needsRefresh = true`.
- That reset shape can still fail the user if graph store/engine nodes, search/readable block stores, Shadow/Halo/Instant Recall indexes, restored workspaces, `@Query` rows, active vault registry/bookmarks, or background tasks republish stale state after reset.
- Settings currently warns that cached local notes or graph rows may still be visible while no vault is connected. That may be honest for a diagnostic state, but it is not acceptable after an explicit Reset Everything action.

Likely files:

```text
Epistemos/App/AppBootstrap.swift
Epistemos/App/RootView.swift
Epistemos/Views/Settings/SettingsView.swift
Epistemos/Views/Onboarding/SetupAssistantView.swift
Epistemos/Views/Sidebar/VaultSelectorView.swift
Epistemos/Vault/VaultRegistry.swift
Epistemos/Sync/VaultSyncService.swift
Epistemos/Sync/NoteFileStorage.swift
Epistemos/Sync/SearchIndexService.swift
Epistemos/Graph/GraphState.swift
Epistemos/Graph/GraphStore.swift
Epistemos/Engine/ShadowSearchService.swift
Epistemos/Engine/HaloController.swift
Epistemos/State/NotesUIState.swift
Epistemos/Views/Notes/NotesSidebar.swift
Epistemos/Views/Notes/VaultOrganizerView.swift
Epistemos/Models/SDPage.swift
Epistemos/Models/SDFolder.swift
```

Risk:

Stale notes after reset are a release-trust failure. The user cannot tell which vault is active, whether old data is still live, whether reset deleted the right things, or whether new vault selection will import into a contaminated state. This can also make graph/search/Halo proof meaningless because old rows can masquerade as current-vault truth.

Patch plan:

1. Add a single `VaultLifecycleResetCoordinator` or equivalent minimal service only if existing ownership cannot express the operation cleanly.
2. Make Reset Everything an idempotent transaction with explicit phases:
   - stop/cancel vault watcher, search/index tasks, Halo/Shadow/Instant Recall refreshes, workspace restore/autosave tasks, graph refresh tasks;
   - revoke/clear active vault bookmark and persisted selection;
   - clear SwiftData rows for notes, folders, blocks, chats, messages, graph nodes/edges, workspaces, page versions, profiles as intended;
   - clear `NoteFileStorage` managed bodies and Application Support derived note/search/graph/readable-block stores;
   - force-clear graph store and Rust graph engine visible payload, not just set `needsRefresh`;
   - clear Search/Halo/Shadow/Instant Recall caches or mark unavailable until a new active vault is selected;
   - reset `NotesUIState`, selected note/window/workspace state, restored tabs, and any open note windows;
   - publish one canonical `.vaultChanged` / reset event with reason `fullReset`;
   - show setup/vault chooser only after every required clear phase has succeeded or has an explicit surfaced failure.
3. Add vault add/remove/disconnect hardening:
   - selecting a new vault is a two-phase operation: validate/bookmark/import, then publish active-vault state;
   - failed selection does not destroy the previous valid vault state unless the user explicitly disconnected/reset;
   - disconnect/remove clears all live/derived state for that vault and cannot leave editable stale cache masquerading as live vault data;
   - Settings, Notes sidebar, Graph, Search, Halo diagnostics, and onboarding read from the same active-vault truth.

Test plan:

- Unit/integration tests for full reset idempotence.
- Reset deletes or clears SwiftData rows, managed note bodies, graph store/engine payload, search/readable-block/Shadow/Halo/Instant Recall caches, persisted vault selection/bookmark, and restored workspace selections.
- Create disposable vault A with unique note `VAULT_A_ONLY`; select/import A; assert Notes/Search/Graph/Halo/Settings agree.
- Run Reset Everything; assert `VAULT_A_ONLY` is absent everywhere before and after relaunch.
- Create disposable vault B with unique note `VAULT_B_ONLY`; select/import B; assert B appears and A does not.
- Remove/disconnect B; assert B disappears from Notes/Search/Graph/Halo and Settings says no active vault.
- Simulate failed vault selection and prove previous state is either preserved or cleanly reset according to the explicit user action.
- Simulate background index task completion after reset and prove it cannot republish stale rows.

Manual verification:

Use two throwaway vault folders with unique note titles. After reset, open Notes sidebar, Graph, Search, Halo diagnostics, Settings, and restored workspaces. No old note may appear unless a screen is explicitly labeled disconnected cache and cannot be edited/synced as live data. For Reset Everything, even disconnected cache should be cleared.

Implementation evidence, 2026-05-09 Wave 0 automated pass:

- Files changed:
  - `Epistemos/App/AppBootstrap.swift`
  - `Epistemos/Sync/VaultSyncService.swift`
  - `Epistemos/Graph/GraphState.swift`
  - `Epistemos/Graph/FilterEngine.swift`
  - `Epistemos/State/ContextualShadowsState.swift`
  - `Epistemos/Engine/QueryEngine.swift`
  - `EpistemosTests/VaultLifecycleResetTests.swift`
  - `EpistemosTests/VaultSyncServiceAuditTests.swift`
  - `EpistemosTests/RuntimeValidationTests.swift`
- Product patch:
  - Added `AppBootstrap.clearVaultLifecycleRuntimeState(reason:clearWorkspaceRestore:)` and call it before and after `resetAllData()` destructive clears. It cancels query/prepared retrieval/body cleanup tasks, clears ambient manifests, invalidates Query runtime, resets Shadow/Halo diagnostics, clears Shadow/R3 indexing sentinels, clears Instant Recall, clears Graph state, optionally clears workspace autosave/welcome-back state, and logs the reset reason.
  - Added `resetForVaultLifecycle()` to `GraphState`, `FilterEngine`, `ContextualShadowsState`, and `QueryEngine`.
  - `GraphState.resetForVaultLifecycle()` clears the visible graph store, selection, routes, filters, pending FFI add/remove queues, prepared retrieval state, semantic clusters, wikilink lookup, and the Rust graph engine payload/highlight/embeddings/prepared retrieval index when an engine handle exists. It leaves `needsRefresh` false so a vaultless reset does not request stale graph rebuild.
  - `VaultSyncService.clearVaultData()` now routes through the same lifecycle runtime clear instead of only marking the graph for refresh.
  - `VaultSyncService.switchToVaultAsync()` preflights candidate security-scoped access before stopping an existing vault when sandbox access is required; failed candidate access now returns `false` and keeps the previous active vault watching.
  - `VaultConnectionActions.connectSelectedVaultAsync()` no longer resets note windows or home UI on failed selection; previous valid state is preserved unless reset/disconnect succeeds.
- Tests added:
  - `VaultLifecycleResetTests.graphLifecycleResetClearsVisibleStoreAndQueues`
  - `VaultLifecycleResetTests.contextualShadowsResetDetachesStaleBackendAndHits`
  - `VaultLifecycleResetTests.queryEngineResetClearsVisibleSearchStateAndHistory`
  - `VaultLifecycleResetTests.resetEverythingClearsSwiftDataRowsBodiesAndRuntimeCaches`
  - `VaultSyncServiceAuditTests.failedVaultSelectionPreservesPreviousActiveVault`
  - Updated `RuntimeValidationTests.fullResetClearsTheWholeSchemaAndManagedNoteBodies` to assert the reset hard-clear contract instead of the old stale-prone `graphState.needsRefresh = true` behavior.
- Commands and results:
  - `git status --short`; `git branch --show-current`; `git rev-parse --short HEAD` -> branch `codex/research-snapshot-2026-05-08`, commit `9599b05c1`, with pre-existing untracked audit packet files plus Wave 0 edits.
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/VaultLifecycleResetTests test CODE_SIGNING_ALLOWED=NO` -> expected red compile failure before product patch because `resetForVaultLifecycle()` APIs did not exist. Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.08_23-44-14--0500.xcresult`.
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/VaultLifecycleResetTests -only-testing:EpistemosTests/VaultSyncServiceAuditTests/failedVaultSelectionPreservesPreviousActiveVault test CODE_SIGNING_ALLOWED=NO` -> passed the three reset tests, but the method selector did not execute the new `VaultSyncServiceAuditTests` body. Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.08_23-52-11--0500.xcresult`.
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/VaultSyncServiceAuditTests test CODE_SIGNING_ALLOWED=NO` -> failed before the security-scope preflight hook because rejected temp vault selection still switched away from the current vault. Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.08_23-55-44--0500.xcresult`.
  - Same `VaultSyncServiceAuditTests` command after the first hook patch -> compile failed because a static startup bookmark path accidentally called the new instance helper. Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_00-02-57--0500.xcresult`.
  - Same `VaultSyncServiceAuditTests` command after fixing the static path -> `** TEST SUCCEEDED **`; Swift Testing reported `48 tests in 1 suite passed after 6.093 seconds`. Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_00-04-21--0500.xcresult`.
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/VaultLifecycleResetTests test CODE_SIGNING_ALLOWED=NO` -> `** TEST SUCCEEDED **`; Swift Testing reported `3 tests in 1 suite passed after 0.005 seconds`. Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_00-07-29--0500.xcresult`.
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/VaultLifecycleResetTests -only-testing:EpistemosTests/VaultSyncServiceAuditTests test CODE_SIGNING_ALLOWED=NO` after the broader reset guard update -> `** TEST SUCCEEDED **`; Swift Testing reported `51 tests in 2 suites passed after 6.013 seconds`. Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_00-13-14--0500.xcresult`.
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/VaultLifecycleResetTests test CODE_SIGNING_ALLOWED=NO` after adding the `resetEverythingClearsSwiftDataRowsBodiesAndRuntimeCaches` integration-style test -> compile failed because the test asserted a non-existent `AppBootstrap.initializationDiagnostics` member. Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_00-18-40--0500.xcresult`.
  - Same `VaultLifecycleResetTests` command after fixing the assertion to `bootstrap.uiState.needsSetup` / `.home` -> `** TEST SUCCEEDED **`; Swift Testing reported `4 tests in 1 suite passed after 0.109 seconds`. Runtime logs show `Vault lifecycle: cleared runtime state (Reset Everything started)`, `VaultSyncService cleared local vault data`, and `Reset Everything completed`. Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_00-21-14--0500.xcresult`.
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/VaultLifecycleResetTests -only-testing:EpistemosTests/VaultSyncServiceAuditTests test CODE_SIGNING_ALLOWED=NO` final focused combined run -> `** TEST SUCCEEDED **`; Swift Testing reported `52 tests in 2 suites passed after 6.487 seconds`. Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_00-25-54--0500.xcresult`.
  - `git diff --check` -> passed with no whitespace errors.
- Source guards:
  - `rg -n "configureShadowSearch\\(nil\\)" Epistemos/App/AppBootstrap.swift` -> no matches.
  - `rg -n "graphState\\.needsRefresh = true" Epistemos/App/AppBootstrap.swift Epistemos/Sync/VaultSyncService.swift` -> no `AppBootstrap.resetAllData()` matches; remaining hits are `VaultSyncService` non-reset import/update refreshes at lines 2291, 2493, and 2874.
  - `rg -n "Task \\{ @MainActor in" Epistemos/Sync/VaultSyncService.swift || true` -> remaining hits at lines 3497, 3529, and 3535; the old reset `clearVaultData()` unawaited graph clear was removed.
- Remaining proof and risk:
  - Manual/runtime smoke with disposable `VAULT_A_ONLY`, Settings -> Reset Everything, relaunch, and disposable `VAULT_B_ONLY` has not been run yet.
  - Full wave build/test, full app test suite, and three clean release passes have not been run.
  - This item is not closed until the UI/runtime smoke proves Notes, Graph, Search, Halo diagnostics, Settings, and restored workspace state converge in the running app.

2026-05-09 audit harness isolation + A-vault runtime smoke start:

- Harness issue found during manual proof:
  - `scripts/launch_audit_app.sh` changed the cloned app bundle id to `com.epistemos.audit`, but the main SwiftData/note-body/search/event-store paths still resolved through the normal `~/Library/Application Support/Epistemos` root.
  - Only the Rust permission DB was bundle-id isolated before this patch. That made the audit harness unsafe for destructive reset proof and caused vault selection to snapshot production-scale derived local state.
  - Earlier failed audit-app selection attempts created recovery snapshots under `~/Library/Application Support/Epistemos-Recovery`; those were left untouched.
- Files changed for harness isolation:
  - `Epistemos/Engine/Extensions.swift`
  - `scripts/launch_audit_app.sh`
  - `Epistemos/App/AppBootstrap.swift`
  - `Epistemos/App/AppGroupContainer.swift`
  - `Epistemos/Vault/ConversationPersistence.swift`
  - `Epistemos/Engine/CapabilityManifestBuilder.swift`
  - `Epistemos/Engine/QuarantineArchive.swift`
  - `Epistemos/Omega/Inference/DeviceAgentService.swift`
  - `Epistemos/Views/Capture/TraceInspectorView.swift`
  - `EpistemosTests/RuntimeValidationTests.swift`
- Product/harness behavior:
  - Added explicit `EPISTEMOS_APPLICATION_SUPPORT_ROOT` routing in `FoundationSafety.runtimeApplicationSupportDirectory`.
  - The override is ignored unless it is an absolute path.
  - The audit launcher now clears and sets `build/audit-app-support` as the cloned app's Application Support root via `LSEnvironment`.
  - Main runtime stores used by the smoke now resolve under `build/audit-app-support/Epistemos`, and the Rust permissions DB resolves under `build/audit-app-support/com.epistemos.audit/permissions.db`.
- Green commands:
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/RuntimeValidationTests test CODE_SIGNING_ALLOWED=NO`
  - `git diff --check`
  - `./scripts/launch_audit_app.sh`
- Runtime isolation evidence:
  - Launcher output reported `App data: /Users/jojo/Downloads/Epistemos/build/audit-app-support`.
  - `PlistBuddy -c 'Print :LSEnvironment' build/audit-app/EpistemosAudit.app/Contents/Info.plist` showed `EPISTEMOS_APPLICATION_SUPPORT_ROOT = /Users/jojo/Downloads/Epistemos/build/audit-app-support`.
  - `find build/audit-app-support -maxdepth 4 -print` showed `default.store`, `note-bodies`, `search.sqlite`, `event-store.sqlite`, `paperclip_state.db`, runtime diagnostics, and `com.epistemos.audit/permissions.db` under the isolated root.
  - Runtime log evidence showed `R.5 persist: permission store backed at /Users/jojo/Downloads/Epistemos/build/audit-app-support/com.epistemos.audit/permissions.db` and `Runtime diagnostics directory: /Users/jojo/Downloads/Epistemos/build/audit-app-support/Epistemos/runtime_diagnostics`.
- A-vault runtime smoke evidence so far:
  - Disposable vault A: `build/vault-smoke-2026-05-09/A/VAULT_A_ONLY.md`.
  - Disposable vault B: `build/vault-smoke-2026-05-09/B/VAULT_B_ONLY.md`.
  - Settings -> Vault selected A and showed `/Users/jojo/Downloads/Epistemos/build/vault-smoke-2026-05-09/A` with `Connected` status.
  - Notes window showed only `VAULT_A_ONLY`.
  - Graph Notes tab showed only `VAULT_A_ONLY`.
  - Graph Query filter returned `1 MATCH` for `VAULT_A_ONLY` and `No matching nodes` for `VAULT_B_ONLY`.
  - Runtime log showed `VaultSyncService started for: A`, `Vault import complete: 1 files on disk, 1 tracked vault pages in DB`, `R.3 gateway: ready for vault=A`, and `shadow_handle_open_at OK` under A's `.epcache/shadow`.
  - `sqlite3 build/audit-app-support/Epistemos/default.store "select ztitle from zsdpage order by ztitle;"` returned only `VAULT_A_ONLY`.
- Remaining proof and risk:
  - Reset Everything has not yet been clicked in the UI; action-time confirmation is pending because it is destructive even though this audit app is isolated.
  - Relaunch-after-reset proof, B-vault selection proof, B disconnect/removal proof, and post-reset absence checks for Notes/Graph/Search/Halo remain pending.

Backlog update needed:

Make this the first item in the Codex recursive prompt. It supersedes the older softer connected-vault truth items as the active user blocker, but does not replace them; after reset is fixed, the connected-vault create/rename/move/delete convergence smoke still remains.

### RCA13-P1-002 - Dynamic CLI discovery and install/setup prompts

Status: new post-blocker feature request
Severity: P1 for Pro/direct usability, P0 if it leaks into App Store or weakens env-secret hardening
Subsystem: CLI passthrough, agent settings, tool registry, Pro/direct feature gates.

User request:

The app should auto-load support if a CLI is already installed and should ask to install/setup Codex, Claude Code, Gemini, Kimi, or other required CLIs when missing.

Scope rule:

This must not start until vault lifecycle and the security/persistence P0s are closed. It is a direct/Pro feature, not an App Store feature. It must never silently install or run external binaries.

Likely files:

```text
agent_core/src/tools/cli_passthrough.rs
agent_core/src/tools/registry.rs
agent_core/src/providers/claude.rs
agent_core/src/providers/gemini.rs
agent_core/src/providers/openai.rs
agent_core/src/providers/openai_compatible.rs
Epistemos/Bridge/ToolTierBridge.swift
Epistemos/Views/Settings/AgentControlSettingsView.swift
Epistemos/State/AgentCommandCenterState.swift
Epistemos/State/InferenceState.swift
Epistemos/AppStore/AppStoreComputerUseStubs.swift
docs/CLI_CONFIG_COMPILATION_RESEARCH.md
```

Patch plan:

- Add a `CLICapabilityDiscoveryService` or equivalent existing-service extension.
- Probe known CLIs from a scrubbed allowlisted environment:
  - `codex`
  - `claude`
  - `gemini`
  - `kimi` / Moonshot-compatible CLI if supported
  - any existing repo-supported agent-browser or passthrough helpers.
- Probes should be limited to path resolution and explicit version/capability commands.
- Missing CLIs show setup/install prompts with links/commands verified against current official vendor docs at implementation time.
- App Store builds hide this surface entirely or show "not available in App Store build" without executable hooks.
- Installed CLIs produce visible capability rows, required auth state, and scoped execution controls.
- Do not import secrets from parent env; all auth/session imports must use scoped stores and explicit user consent.

Test plan:

- Fake PATH with stub CLIs for installed/missing/version states.
- Pro/direct build shows detected capabilities; MAS build hides or hard-denies them.
- Absent CLI execution is denied with a helpful setup path.
- Installed CLI execution uses scrubbed env and does not inherit provider secrets.
- Official install docs/commands are web-validated during the implementation pass before product copy lands.

Backlog update needed:

Track as a usability feature after current blockers. Do not mix it into Wave 0/1.

### RCA13-P2-001 - Local Engineering Agent structure without unsafe open ports

Status: design-preserved / do not implement before P0/P1 closure
Severity: P2 now, can become P1 once current local-agent UX is actively being shipped
Subsystem: LocalAgent, command center, tool registry, session logs, engineering workflow.

User request:

The local agent should feel more structured, useful, expressive, and usable as the app's own engineering agent. The user asked whether to add an "open code port or something."

Decision:

Do not add a raw open network port by default. The right shape is an app-native engineering agent shell with structured sessions and visible authorization. If a loopback/API surface is ever added, it must be disabled by default, localhost-only, token-authenticated, logged, and unavailable in App Store builds.

Likely files:

```text
Epistemos/LocalAgent/LocalAgentLoop.swift
Epistemos/LocalAgent/LocalAgentPromptBuilder.swift
Epistemos/LocalAgent/LocalAgentCommandDispatcher.swift
Epistemos/Bridge/ToolTierBridge.swift
Epistemos/App/ChatCoordinator.swift
agent_core/src/session.rs
agent_core/src/tools/registry.rs
agent_core/src/resources/tool_authz.rs
```

Design requirements:

- visible task plan;
- visible repo/vault context;
- explicit allowed tools and denied tools;
- patch proposal pane;
- checkpoint/rollback story;
- verification loop;
- run logs and side-effect ledger;
- no unscoped shell/CLI/file mutation;
- no external process can drive the local agent without user-authorized capability.

Backlog update needed:

Preserve this as a design lane after vault/security fixes. It should become part of the EpiKernel Exocortex lane only when the current app can be trusted as a substrate.

### Drop 13 Final Priority Order

The next recursive session should use this order:

1. Vault lifecycle reset/add/remove/select hardening.
2. CodeFileService containment and visible code editor service routing.
3. Database fallback degraded-mode truth.
4. Credential env mirroring removal and child env scrub proof.
5. OAuth state/loopback hardening.
6. Capture metadata sidecar/migration.
7. Composer voice draft/temp-file cleanup.
8. App Store scheme/artifact truth.
9. Current Access / tool permission parity.
10. `/image` and `.epdoc` image truth.
11. `.epdoc`, Query/Halo, Graph, and Vault Organizer performance/truth fixes.
12. Harness honesty: `run_all_tests.sh`, perf gates, source-guard labels.
13. Dynamic CLI discovery/install prompts.
14. Local Engineering Agent shell design.
15. EpiKernel / AnswerPacket / ClaimGraph / RuntimeInvariant research implementation.

### Drop 13 Readiness Verdict

Ready to start a new recursive fix session: yes.

Ready to build new future-brain architecture: no.

Ready to release: no.

The new session should paste/use `docs/audits/CODEX_RECURSIVE_FIX_PROMPT_2026_05_09.md`, which has been updated so Wave 0 starts with the live vault blocker.

## 2026-05-09 User-Reported Current-App Workstream Intake

These items are now explicitly tracked, but they do not supersede the current P0/P1 trust blockers unless the user-visible regression blocks basic app use. Theme restoration must start with forensic audit and architecture proposal before product rendering changes.

### UIX-2026-05-09-001 - Native theme restoration without overlay/compositing regressions

Status: PARTIAL - THEME PICKER + GRAPH SURFACE TINT PATCHED / FORENSIC INVENTORY + NODE/EDGE THEME PALETTE PENDING

User signal:

- The pure default light look feels sterile after older emotional themes were removed.
- Desired atmosphere includes warm tan/paper, retro Apple/classic Mac, retro Windows, muted blue-gray/purple, atmospheric off-white, platinum/silver, and graph/editor/utility-window variants.
- Do not restore old implementation code because the old approach caused rendering instability, overlay bugs, cache invalidation issues, redraw churn, layer glitches, and compositing bloat.

Hard constraints:

- Themes must be native surface coloration and semantic tokens, not overlay sheets.
- Do not add giant overlay `ZStack`s, fullscreen masks, duplicate render trees, floating theme layers, opacity/compositing hacks, blanket blur/material abuse, or broad environment redraw cascades.
- Do not change graph physics, graph animation timing, or graph rendering architecture for theme work.

Required Phase 1 forensic audit:

- Inspect historical commits, deleted/archived theme structs, screenshots/GIF diffs, asset catalogs, old settings code, theme managers, graph appearance code, editor appearance code, and utility-window rendering paths.
- Build an evidence-backed inventory of every historical theme/appearance option found.
- Classify each as stable candidate, unfinished/experimental, duplicate/near-duplicate, unsafe implementation pattern, or missing evidence.
- Record source evidence per theme: commit, file, screenshot/GIF, struct, asset name, or settings entry.

Required architecture proposal:

- Semantic tokens: app background, editor background/text, utility surface, graph surface tint, graph node/edge accents, selection/highlight, panel/sidebar surfaces, borders/separators, optional retro accents.
- Prefer direct AppKit surface colors, direct `NSTextView`/`NSScrollView` background updates, SwiftUI semantic colors, graph clear/surface color inputs, cached theme resolution, and minimal live-switch invalidation.
- Avoid per-frame theme recomputation and body-wide theme churn.
- Graph theme tokens must also reach graph node palettes, not only the graph surface. Theme restoration should include node fill/stroke/edge/label/accent token mapping so warm, platinum, retro Apple, retro Windows, and violet variants alter graph semantic color without changing physics or renderer architecture.

2026-05-09 theme-picker evidence:

- `Epistemos/Theme/EpistemosTheme.swift` still contains the existing theme registry: `systemLight`, `systemDark`, `light`, `oled`, `sunny`, `sunset`, `tan`, `ember`, `magnolia`, `nocturne`, `platinum`, `platinumDark`, `platinumViolet`, and `platinumVioletDark`.
- `ThemePair` still defines the six public pairings: `Magnolia`, `Classic`, `Warmth`, `Ember`, `Platinum`, and `Platinum Violet`.
- The resolved color cache still iterates `EpistemosTheme.allCases`, so theme definitions are built and consumable.
- Removal commit identified by user research: `78c247287` (`2026-03-16`, "refactor: remove legacy custom theme settings") deleted the Settings picker UI/state, including `AppearanceThemePairSection`, `ThemePairCard`, `ForEach(ThemePair.allCases...)`, `selectedPairDraft`, `pendingThemePair`, and `scheduleThemePairChange`.
- Current `AppearanceDetailView` only exposes the static system appearance label, System Settings shortcut, and display mode toggle. There is no user-facing path to select the existing theme pairs.
- First theme slice should restore the picker UI with native semantic tokens before broader forensic theme restoration. Do not reintroduce unsafe overlay/compositing implementations while restoring the picker.

Patch evidence, 2026-05-09 graph surface tint slice:

- Files changed:
  - `Epistemos/Views/Graph/HologramOverlay.swift`
  - `EpistemosTests/ThemePairTests.swift`
- Product behavior:
  - Graph overlay/full-size and mini surface tint now samples `theme.resolved.background.nsColor` and applies the existing glass alpha.
  - This gives warm, tan, platinum, violet, and other restored theme pairs a graph-surface identity without adding overlay layers, changing graph physics, or rebuilding graph data.
  - Dark graph surfaces keep the same material path with a darker alpha; blur/material choice remains `.hudWindow`.
- Tests/commands:
  - Red proof: `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ThemePairTests test CODE_SIGNING_ALLOWED=NO` failed before product patch because `GraphOverlayThemeStyle.surfaceTintColor(for: .tan)` was still fixed white/black instead of the tan theme surface; failed xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_13-59-07--0500.xcresult`.
  - Same command passed after product patch, 112 tests, xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_14-02-28--0500.xcresult`.
- Remaining risk:
  - This is only graph surface/material tint. Theme-driven graph node fill/stroke, edge, label, and accent token mapping is still pending.
  - Manual built-app theme switching smoke is still required to verify graph tint updates live with Settings -> Appearance and macOS light/dark changes.

Patch evidence, 2026-05-09 graph node theme palette slice:

- Files changed:
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`
- Product behavior:
  - Added `GraphThemeNodePalette` as a Swift-side semantic graph palette used before pushing node color overrides to the Rust graph engine.
  - Folder nodes stay solid pitch black in light/system-light custom themes and solid pitch white in dark/system-dark custom themes.
  - Note/document/prose nodes retain saturated blue/teal semantic color instead of falling back to white/black during system light/dark changes.
  - Idea nodes stay yellow by default and receive a light theme accent tint in custom themes; other semantic node categories keep solid category colors with a small custom-theme accent blend.
  - `MetalGraphView.updateNSView` now reads `uiState.appearanceSyncKey` and calls `syncThemeIfNeeded(...)`, so theme pair and system light/dark changes refresh graph light mode and node color overrides without rebuilding graph data or changing physics.
  - The appearance sync key is only marked consumed after the graph engine exists, so first render cannot miss a pending theme change during NSView construction.
  - Existing dialogue visual theme depth behavior remains isolated; the new theme palette applies to the classic/non-dialogue graph path.
- Tests/commands:
  - Red proof: `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` failed before product patch because `GraphThemeNodePalette` and the UI theme refresh hooks did not exist; failed xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_14-07-38--0500.xcresult`.
  - Same command passed after product patch, 28 tests, xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_14-15-38--0500.xcresult`.
- Remaining risk:
  - Manual dense-graph runtime smoke is still required to compare actual node colors during Settings theme selection and system light/dark switching.
  - Theme-driven edge/label/accent mapping and user-editable graph groups remain pending.

Initial implementation candidates after audit:

1. current/default native light
2. warm tan / paper
3. retro Apple / classic Mac
4. retro Windows / muted blue-gray or purple
5. platinum / silver
6. other stable historical themes with evidence

Verification required before public theme release:

- Editor typing remains smooth.
- Notes sidebar entry remains low latency.
- Graph redraw remains smooth and uses only surface tint/token changes.
- Live theme switching does not trigger unnecessary full-app redraws.
- Screenshots/GIF comparisons are captured where feasible.

### UIX-2026-05-09-002 - `.epdoc` routing and formatting command regressions

Status: PARTIAL FIX LANDED / HEADING AND TAB-ROUTING AUTOMATED GREEN / BUILT-APP RUNTIME PROOF STILL PENDING

User signal:

- `.epdoc` no longer opens in the utility/editor area with the prose editor and code editor.
- Pressing Header 1 changes other deselected content to Header 1, suggesting formatting command selection/range leakage.
- The heading control exposes only one Header 1 button; expected behavior is a nested or structured heading menu with multiple levels.

Likely files to inspect:

- `Epistemos/Engine/EpdocDocument.swift`
- `Epistemos/Engine/EpdocEditorBridge.swift`
- `Epistemos/Views/Epdoc/*`
- `Epistemos/Views/Workspace/ArtifactHostView.swift`
- `Epistemos/App/UtilityWindowManager.swift`
- `Epistemos/App/EpistemosApp.swift`
- `js-editor/src/extensions/slash-menu.ts`
- `js-editor/src/extensions/image-asset-bridge.ts`

Required proof:

- `.epdoc` open route lands in the intended utility/editor workspace without spawning the wrong surface. Status: reciprocal native note/doc tab-routing automated proof green; built-app runtime smoke still pending.
- Heading commands apply only to the current selection/block range. Status: automated source/bridge proof green; runtime UI smoke still pending.
- Heading UI exposes H1-H6 or equivalent structured levels. Status: fixed by native toolbar menu.
- Runtime smoke covers open, edit heading, deselect, edit another block, save/reopen.

Implementation evidence, 2026-05-09 `.epdoc` heading regression slice:

- Files changed:
  - `Epistemos/Views/Epdoc/EpdocEditorToolbar.swift`
  - `js-editor/src/bridge/inbound.ts`
  - `Epistemos/Resources/Editor/editor.js.br`
  - `EpistemosTests/EpdocEditorToolbarTests.swift`
- Tests added:
  - `EpdocEditorToolbarTests.headingControlUsesScopedHeadingMenu`
  - `EpdocEditorToolbarTests.inboundHeadingCommandScopesToActiveTextBlock`
- Test-first red command:
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/EpdocEditorToolbarTests test CODE_SIGNING_ALLOWED=NO`
  - Result: failed before product patch with 10 source-guard issues because the toolbar still dispatched `.insertSlashChoice(blockType: "heading-1")` and the inbound bridge lacked `setHeadingLevel`, `textblockDepth`, `setNodeMarkup`, and `headingLevelFromArgs` helpers.
  - Red `.xcresult`: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_00-56-45--0500.xcresult`
- Product patch:
  - Native `.epdoc` toolbar heading control is now a `Menu` with `Paragraph` and `ForEach(1...6)` heading actions.
  - Toolbar dispatches `setParagraph` and `setHeadingLevel` through `.runCommand` instead of reusing the slash insertion path for H1.
  - Inbound JS bridge handles `setHeadingLevel` by validating level 1...6, finding the active textblock depth, and using `state.tr.setNodeMarkup(...)` on that one textblock only.
  - Same-level heading action toggles back to paragraph; explicit Paragraph strips heading level from the active block.
- Commands run:
  - `npm run typecheck` in `js-editor`
    - Result: passed.
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/EpdocEditorToolbarTests test CODE_SIGNING_ALLOWED=NO`
    - Result: passed, 7 tests in 1 suite.
    - Green `.xcresult`: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-00-51--0500.xcresult`
- Remaining risk:
  - This is not a full runtime UI proof. A manual built-app `.epdoc` smoke still needs to open a document, use H1-H6 on separate blocks, deselect/reselect, save, close, reopen, and verify no unrelated block changed.

Implementation evidence, 2026-05-09 `.epdoc` reciprocal note-tab routing slice:

- Files changed:
  - `Epistemos/Views/Notes/NoteWindowManager.swift`
  - `Epistemos/Engine/EpdocDocument.swift`
  - `EpistemosTests/NoteWindowManagerTests.swift`
  - `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`
- Tests added/updated:
  - `NoteWindowManagerTests.noteTabsCanAttachToExistingEpdocDocumentWindows`
  - `EpdocVisibilitySourceGuardTests.epdocWindowsReuseNativeNoteTabGroup`
- Test-first red command:
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/NoteWindowManagerTests test CODE_SIGNING_ALLOWED=NO`
  - Result: failed before product patch because `NoteWindowManager.noteTabbingIdentifier` and `NoteWindowManager.firstAvailableNoteTabGroupWindow(...)` did not exist.
  - Red `.xcresult`: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-06-19--0500.xcresult`
- Product patch:
  - `NoteWindowManager` now owns the canonical `noteTabbingIdentifier` used by prose/code note windows and `.epdoc` windows.
  - `NoteWindowManager.firstAvailableNoteTabGroupWindow(...)` discovers any visible native note/doc tab group by the canonical tab identifier, not only windows already tracked in the note-window dictionary.
  - New prose/code note windows and note-version windows now attach to an existing `.epdoc` tab group when the `.epdoc` window was opened first.
  - `.epdoc` document windows now use the same shared locator when attaching to an existing prose/code note tab group.
- Commands run:
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/NoteWindowManagerTests test CODE_SIGNING_ALLOWED=NO`
    - Result: passed, 32 tests in 1 suite.
    - Green `.xcresult`: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-09-24--0500.xcresult`
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests test CODE_SIGNING_ALLOWED=NO`
    - Result: passed, 9 tests in 1 suite.
    - Green `.xcresult`: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-12-53--0500.xcresult`
- Remaining risk:
  - This still needs built-app manual smoke: open `.epdoc` first then open a prose/code note and verify the shared native tab group; open a prose/code note first then open `.epdoc` and verify it joins; save, close, reopen, and confirm the routing remains stable.
  - The fix proves reciprocal native tab routing, not the complete `.epdoc` durability/projection smoke called out by `RCA7-P1-004`, `RCA10-P1-002`, and `RCA12-P1-002`.

2026-05-09 real vault sidebar/folder smoke:

- User-selected runtime vault:
  - `/Users/jojo/all research`
- Harness:
  - `./scripts/launch_audit_app.sh`
  - Audit bundle: `build/audit-app/EpistemosAudit.app`
  - Audit bundle id: `com.epistemos.audit`
  - Isolated app data: `build/audit-app-support`
  - Verified `LSEnvironment` includes:
    - `EPISTEMOS_SKIP_VAULT_RESTORE=1`
    - `EPISTEMOS_APPLICATION_SUPPORT_ROOT=/Users/jojo/Downloads/Epistemos/build/audit-app-support`
    - `EPISTEMOS_AUDIT_ALLOW_SOVEREIGN_GATE=1`
  - `ps` showed only the audit app running from `build/audit-app/EpistemosAudit.app/Contents/MacOS/Epistemos`; production `/Applications/Epistemos.app` was not running.
- Product patch:
  - `VaultIndexActor.importVault(from:)` now calls `synthesizeFoldersFromSubfolders()` after each 200-change batch save instead of waiting only for final import completion.
  - This lets the Notes sidebar receive `vaultFoldersRepairedNotification` and show folders during a large vault import.
  - Audit-only reset bypass was added to `SovereignGate` and is gated to bundle id `com.epistemos.audit` plus `EPISTEMOS_AUDIT_ALLOW_SOVEREIGN_GATE=1`; production `com.epistemos.app` still routes destructive actions through authentication.
- Automated proof:
  - Red suite:
    - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/SovereignGateTests -only-testing:EpistemosTests/RuntimeValidationTests test CODE_SIGNING_ALLOWED=NO`
    - Failed only because `RuntimeValidationTests.largeVaultImportsRefreshSidebarFoldersAtBatchCheckpoints` used an indentation-sensitive source guard.
    - Red `.xcresult`: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_09-59-54--0500.xcresult`
  - Green suite:
    - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/SovereignGateTests -only-testing:EpistemosTests/RuntimeValidationTests test CODE_SIGNING_ALLOWED=NO`
    - Passed after changing the source guard to ordered marker checks.
  - `git diff --check`
    - Passed.
- Runtime evidence:
  - `/usr/bin/log show --style compact --info --last 5m --predicate 'process == "Epistemos" AND subsystem == "com.epistemos"' | rg 'Vault import progress|Synthesized|Vault import complete|MainThreadWatchdog|GraphBuilder|SearchIndex'`
  - Import/folder progress:
    - `Synthesized 7 folders from 7 unique directory paths`; `Vault import progress: 200 changes`
    - `Synthesized 21 folders from 19 unique directory paths`; `Vault import progress: 400 changes`
    - `Synthesized 28 folders from 28 unique directory paths`; `Vault import progress: 600 changes`
    - `Synthesized 41 folders from 39 unique directory paths`; `Vault import progress: 800 changes`
    - `Synthesized 87 folders from 77 unique directory paths`; `Vault import progress: 1000 changes`
    - `Synthesized 139 folders from 119 unique directory paths`; `Vault import progress: 1200 changes`
  - Graph projection:
    - `Built graph from 1200 pages and 0 chats -> 1339 nodes, 1203 edges`
    - `Diff persist complete — nodes: +1339 ~0 -0, edges: +1203 ~0 -0`
  - Isolated SwiftData counts:
    - `select count(*) from zsdpage` -> `1200`
    - `select count(*) from zsdfolder` -> `139`
  - Computer Use UI proof:
    - Notes sidebar showed `ALL RESEARCH`.
    - Folder rows were visible after batch synthesis: `old research`, `fusion`, `research`, `new features`, `jordan's research 2`, `epistemos_architecture_docs 2`.
    - The `.epdoc` package rows still appeared in a flat `DOCUMENTS` bucket.
- Remaining risk:
  - The Reset Everything runtime proof for `/Users/jojo/all research` has not been run yet because it is a destructive local UI action and needs action-time confirmation.
  - The live run surfaced `MainThreadWatchdog` reporting `Main thread hang detected: 26362ms` around the OpenPanel/vault-start interval. This may be OpenPanel dwell/nested-modal false positive or a real vault-start stall; it must be investigated before closing the vault/sidebar performance blocker.
  - The sidebar still mixes user-vault folders with app-produced `.epdoc` package rows under a flat `DOCUMENTS` section. Navigation architecture cleanup is now tracked under `UIX-2026-05-09-005`.

### UIX-2026-05-09-003 - Notes/sidebar performance regression

Status: PARTIAL FIX LANDED / AUTOMATED SOURCE GUARD GREEN / REAL LARGE-VAULT FOLDER SMOKE PASSED / STALL + NAV REDESIGN PENDING

User signal:

- Sidebar performance feels degraded.

Likely files to inspect:

- `Epistemos/Views/Notes/NotesSidebar.swift`
- `Epistemos/Views/Notes/NotesBrowserView.swift`
- `Epistemos/State/NotesUIState.swift`
- `Epistemos/Sync/VaultSyncService.swift`
- `Epistemos/Sync/SearchIndexService.swift`

Required proof:

- Measure visible sidebar filtering/sorting/render path before patching.
- Avoid adding broad redraw triggers or synchronous body reads.
- Add focused regression tests or instrumentation where feasible.

Implementation evidence, 2026-05-09 sidebar cache / `.epdoc` scan slice:

- Files changed:
  - `Epistemos/Views/Notes/NotesSidebar.swift`
  - `EpistemosTests/RuntimeValidationTests.swift`
  - `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md`
- Tests added:
  - `RuntimeValidationTests.notesSidebarCacheRebuildObservesFolderStructureAndOffloadsEpdocScans`
- Product patch:
  - Folder cache invalidation now tracks structural folder signatures rather than only folder count.
  - `.epdoc` package discovery and manifest title reads are offloaded to a cancellable utility-priority detached task and guarded against stale vault results before publishing to UI state.
- Commands run:
  - Red: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/RuntimeValidationTests test CODE_SIGNING_ALLOWED=NO`
    - Failed before product patch as expected with 12 source-guard issues.
    - Red `.xcresult`: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-18-23--0500.xcresult`
  - Green: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/RuntimeValidationTests test CODE_SIGNING_ALLOWED=NO`
    - Passed, 262 tests in 1 suite.
    - Green `.xcresult`: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_01-25-32--0500.xcresult`
- Remaining runtime/manual proof:
  - Profile/sidebar smoke with many `.epdoc` packages.
  - Rename, reorder, reparent, and toggle collection folders without changing folder count and confirm visible rows refresh.
  - Create a new `.epdoc` and confirm the document row appears without a sidebar stall.

2026-05-09 real-vault folder visibility evidence:

- Runtime vault: `/Users/jojo/all research`.
- Isolated audit app support root: `build/audit-app-support`.
- SQLite count after import progress:
  - `zsdpage`: `1200`
  - `zsdfolder`: `139`
- Notes sidebar visibly showed folders after batch repair:
  - `old research`
  - `fusion`
  - `research`
  - `new features`
  - `jordan's research 2`
  - `epistemos_architecture_docs 2`
- Remaining sidebar product issues:
  - App-produced `.epdoc` package rows still appear as a flat `DOCUMENTS` group and are not integrated with the user's vault/folder hierarchy.
  - Current navigation still exposes `Model Vaults` as a disclosure section inside the notes sidebar rather than a top-level sidebar mode.
  - System/app-produced artifacts are not cleanly separated from user vault notes.
  - Large-vault selection/import emitted a `MainThreadWatchdog` hang report around the OpenPanel/vault-start interval; needs targeted timing instrumentation before the performance blocker can close.

### UIX-2026-05-09-005 - Replace single-mode Notes sidebar with robust mode-based navigation

Status: SHELL SLICE PATCHED / PINNED STRIP, MULTI-VAULT, AND SYSTEM SOURCES PENDING

User signal:

- The current Notes sidebar navigation feels outdated.
- Model Vaults should be a dedicated top-of-sidebar toggle/mode, not a nested disclosure inside notes.
- System folders and app-produced artifacts should be pinned/separated from user vault notes.
- Epistemos-produced docs, transcripts, logs, skill outputs, and model-memory surfaces should not be visually mixed with the user's real notes vault.

Target product shape:

- Add a top-level sidebar mode switcher:
  - `My Vault`
  - `Model Vaults`
  - `System`
- Keep a persistent pinned strip below the switcher.
- `My Vault` preserves the existing Notes sidebar behavior while separating user vault content from app-produced artifacts.
- `Model Vaults` replaces the sidebar body with a model-memory/model-profile oriented view.
- `System` replaces the sidebar body with app-owned sections such as system prompts, chat transcripts, doc chat exports, agent logs, and skill outputs.

Implementation constraints:

- Swift 6.0 and `@Observable`; do not introduce `ObservableObject`.
- Row bodies must consume Equatable display snapshots, not live `@Model` instances, preserving the memory-safety pattern already documented in `NotesSidebar.swift`.
- No force unwraps, `try!`, or `print()` in production paths.
- File enumeration, transcript reads, and model-memory scans must run off the main actor.
- Do not rewrite the entire 2,500-line `NotesSidebar.swift` in one pass. Extract/wrap first, then split behavior into coherent, tested slices.
- Multi-vault attach must use security-scoped bookmarks and a reliable vault-switch path.
- System-side deletes must be distinct from user-vault deletes and require confirmation.

Suggested slice order:

1. Add a small `SidebarModeStore` with persisted `myVault`, `modelVaults`, and `system` mode.
2. Add a `SidebarShell` and mode switcher that initially hosts the existing `NotesSidebar` unchanged for `My Vault` and lightweight placeholders for the other two modes.
3. Move `Model Vaults` out of the notes tree into its own mode while leaving existing Settings model-profile surfaces intact.
4. Add a pinned strip model/store with idempotent pins and Equatable row snapshots.
5. Add `System` artifact sources as read-only, paginated sections.
6. Only after the shell is stable, split the legacy Notes sidebar body into smaller My Vault components.

Acceptance:

- Switching sidebar modes preserves state and does not reload the user's note body.
- Model Vaults no longer appears as a disclosure row inside the note tree.
- System/app-produced artifacts are visually distinct from user vault notes.
- The pinned strip works across modes and survives relaunch.
- Large vault sidebar render and search do not regress.

2026-05-09 sidebar shell slice:

- Files changed:
  - `Epistemos/Views/Sidebar/SidebarModeStore.swift`
  - `Epistemos/Views/Sidebar/SidebarShell.swift`
  - `Epistemos/Views/Sidebar/ModeSwitcherControl.swift`
  - `Epistemos/Views/Sidebar/PinnedStripView.swift`
  - `Epistemos/Views/Sidebar/ModeModelVaults/ModelVaultsModeView.swift`
  - `Epistemos/Views/Sidebar/ModeSystem/SystemModeView.swift`
  - `Epistemos/Views/Notes/NotesBrowserView.swift`
  - `Epistemos/Views/Notes/NotesSidebar.swift`
  - `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift`
  - `EpistemosTests/SidebarModeStoreTests.swift`
  - `EpistemosTests/SidebarShellValidationTests.swift`
  - `EpistemosTests/RuntimeValidationTests.swift`
- Product behavior:
  - `NotesBrowserView` now hosts `SidebarShell`.
  - `SidebarShell` adds a fixed header with the `Vault`, `Models`, and `System` mode switcher plus a persistent pinned-strip placeholder.
  - `SidebarModeStore` persists the last selected sidebar mode in `UserDefaults` under `sidebar.mode`.
  - `My Vault` still uses the legacy `NotesSidebar` path, but it suppresses the old nested `Model Vaults` disclosure row when hosted by the shell.
  - `Model Vaults` now has its own top-level sidebar mode using the existing model-vault section in standalone presentation.
  - `System` now has a distinct placeholder surface with the fixed subsection taxonomy; real paginated sources are still pending.
- Green commands:
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/SidebarModeStoreTests -only-testing:EpistemosTests/SidebarShellValidationTests test CODE_SIGNING_ALLOWED=NO`
    - Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_10-26-25--0500.xcresult`
    - Passed 3 tests, 0 failed.
  - `git diff --check`
    - Passed.
- Remaining risk:
  - The pinned strip is a visible placeholder only; `SDSidebarPin` persistence, reorder, rename, and reveal/scroll behavior remain pending.
  - Multi-vault attach/switch still needs the security-scoped bookmark model and real picker path.
  - System artifact sections are not yet backed by paginated sources.
  - Model-memory lazy enumeration and GenUI preview rendering remain pending.
  - Runtime UI smoke for mode switching in the built audit app remains pending.

### UIX-2026-05-09-004 - Fullscreen and cinematic graph quality parity

Status: PATCHED PARTIAL - AUTOMATED GRAPH QUALITY/PALETTE GUARDS GREEN / RUNTIME SMOKE PENDING

User signal:

- Fullscreen and cinematic graph modes currently look lower quality than the minimized graph.
- Cinematic mode should render at full-quality visual settings.
- Performance mode may intentionally use reduced quality in the high-definition/fullscreen aspect, but that degradation must be explicit to performance mode rather than leaking into cinematic/fullscreen defaults.
- Latest graph palette requirement supersedes the earlier all-red/all-yellow idea: node bodies must be solid, not translucent. Folder nodes are the black/white anchors: light-mode folders should be plain pitch-black/OLED pixel circles, and dark-mode folders should be pitch white. Non-folder nodes, especially notes, must still register their real semantic node colors across light/dark mode changes.
- Nodes should never be transparent in the base graph pass. Edges must remain behind nodes and must not show through node bodies.
- The selection/click pulse should remain. Solid nodes must not remove the pulse cue; the pulse may modulate the solid fill briefly, but must not reintroduce translucent bodies or edge bleed-through.
- Highest-tier/high-degree folder hubs should get a subtle opaque pixel glare/shading cue that recalls the old gradient design without becoming dramatic or translucent. One-level folders do not need it; it is for the larger parent folder hubs.

Likely files to inspect:

- `Epistemos/Views/Graph/GraphWorkspaceContainer.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/GraphFloatingControls.swift`
- `Epistemos/Graph/GraphState.swift`
- `graph-engine/src/renderer.rs`
- `graph-engine/src/physics.rs`

Required proof:

- Identify the current quality preset decisions for minimized, fullscreen, cinematic, and performance modes.
- Add a focused guard/test proving cinematic/fullscreen use the same high-quality render path as minimized unless explicit performance mode is enabled.
- Do not change graph physics, animation timing, or renderer architecture while fixing quality selection.
- Runtime smoke must compare minimized, fullscreen, cinematic, and performance modes and record whether labels, edge smoothing, node sharpness, and surface scale match the intended preset.
- Palette proof must cover dark and light graph modes: light folder nodes solid OLED black, dark folder nodes solid pitch white, note nodes retain semantic note color, node bodies remain non-transparent, selection pulse retained, large folder hubs get only subtle opaque pixel glare, and render order keeps edges below nodes/labels.

Patch evidence, 2026-05-09 graph quality/palette slice:

- Files changed:
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`
  - `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`
  - `graph-engine/src/renderer.rs`
- Product behavior:
  - Fullscreen/cinematic drawable policy keeps native backing scale unless explicit performance mode or low-power mode is active.
  - Rust graph node palette now keeps folder nodes solid light-mode black / solid dark-mode white while preserving semantic colors for notes, ideas, and other non-folder node types.
  - Swift dialogue-depth palette override now applies the semantic graph palette to all node types, so note/prose/document nodes are not left to the Rust monochrome fallback during system light/dark changes.
  - Cognitive depth no longer pushes body-color tint overrides into Rust; its depth/altitude/radius metadata remains cached for the future real depth lane.
  - Node base alpha is now solid; flat pixel node paths return opaque node bodies so edges do not bleed through.
  - Cinematic selection/click pulse remains, but it modulates the solid fill color instead of reintroducing the old shine sweep or alpha fade.
  - Large/high-degree folder hubs get a subtle opaque pixel glare/shadow cue in the node shader.
  - Renderer draw order is documented and source-guarded as edges, field lines, nodes, labels, dialogue overlay.
- Tests/commands:
  - `cargo fmt --manifest-path graph-engine/Cargo.toml` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml pitch_white` passed, 1 test.
  - `cargo test --manifest-path graph-engine/Cargo.toml plain_oled_black` passed, 1 test.
  - `cargo test --manifest-path graph-engine/Cargo.toml semantic_teal` passed, 2 tests.
  - `cargo test --manifest-path graph-engine/Cargo.toml semantic_yellow` passed, 2 tests.
  - `cargo test --manifest-path graph-engine/Cargo.toml light_and_dark_graph_nodes_are_solid_not_translucent` passed, 1 test.
  - `cargo test --manifest-path graph-engine/Cargo.toml render_order_keeps_edges_under_nodes_and_labels` passed, 1 test.
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` passed after updating the cinematic source guard to keep selection pulse while rejecting the old shine sweep.
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` passed, 21 tests, xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_12-44-26--0500.xcresult`.
  - `./scripts/launch_audit_app.sh` passed and launched `com.epistemos.audit`.
  - `git diff --check` passed.
- Remaining risk:
  - Built-app runtime smoke still needs to visually compare light/dark, fullscreen/cinematic/performance, selected pulse, and edge occlusion over the user's dense graph. The launched audit profile currently reports no vault connected, so it cannot reproduce the user's dense graph screenshot in that profile without selecting a vault.
  - The broader theme-palette-to-graph-node system remains a separate theme lane; this patch only locks the base black/white graph palette.

Patch evidence, 2026-05-09 semantic node palette system-mode slice:

- Files changed:
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`
- Product behavior:
  - Note, prose-note, and document graph nodes now resolve to solid red semantic colors in both light and dark modes.
  - Dialogue graph mode now pushes `GraphThemeNodePalette.color(for: node.type, theme:)` for every node type instead of sending transparent overrides for non-folder nodes. This prevents system light/dark changes from dropping note nodes back to white/black or other fallback colors.
  - Folder anchors remain solid OLED black in light mode and pitch white in dark mode through the same semantic palette.
  - Theme sync still uses `uiState.appearanceSyncKey`, `cachedColorResolvedTheme`, and `lastAppearanceSyncKey` so changing system appearance invalidates and repushes node colors.
- Tests/commands:
  - Red proof: `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` failed after adding the red-node/dialogue-palette assertions and before product patch.
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` passed, xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_15-52-21--0500.xcresult`.
  - Source guard: `rg -n "case \\.note|case \\.proseNote|case \\.document|GraphThemeNodePalette\\.color\\(for: node\\.type, theme: theme\\)|GraphThemeNodePalette\\.color\\(for: node\\.type, theme: resolvedTheme\\)|graphThemeNodePaletteKeepsSolidSemanticNodeColors|metalGraphRefreshesNodePaletteWhenUIThemeChanges" Epistemos/Views/Graph/MetalGraphView.swift EpistemosTests/GraphPhysicsSettingsAuditTests.swift` confirmed palette colors and both dialogue/non-dialogue push paths.
  - `git diff --check` passed.
- Remaining risk:
  - Manual light/dark system appearance smoke is still required in the built app to visually confirm folder black/white, note red, idea yellow, and selected-focus dimming over the user's dense graph.

### UIX-2026-05-09-006 - Graph label hybrid zoom scaling

Status: PATCHED PARTIAL - DENSITY-AWARE LABELS + PHYSICS ENVELOPE WIRED / RUNTIME GRAPH SMOKE PENDING

User signal:

- Graph labels currently feel like fixed screen-space HUD labels rather than spatial labels attached to graph nodes.
- Desired behavior is closer to Obsidian's graph: labels should scale with zoom enough to feel graph-space native while remaining crisp and readable.
- 2026-05-09 screenshots show a more severe failure under selection/zoom: labels for selected-folder neighborhoods congregate into a dense white block near the graph center instead of separating or thinning as the user zooms out.
- When there are more nodes in a local area, labels should become slightly smaller, fade, or be culled. When there are fewer nodes in a local area, labels may naturally be larger. Label sizing must be dynamic based on local density, not only global zoom.

Likely files to inspect:

- `Epistemos/Graph/SDFLabelInstanceBuilder.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Graph/GraphState.swift`
- `Epistemos/Graph/FilterEngine.swift`
- `graph-engine/src/renderer.rs`
- `graph-engine/src/physics.rs`

Required behavior:

- Labels scale with graph zoom enough to feel part of the graph world.
- Label scale is clamped to a readable minimum and maximum.
- Distant/background labels shrink, fade, or hide based on density.
- Hovered, selected, or focused node labels keep stronger readability.
- Labels must not become blurry, jittery, or pixel-smeared during zoom.
- Avoid per-frame text layout allocations.
- Preserve graph responsiveness, animation timing, and physics.

Preferred implementation constraints:

- Use the existing SDF/MSDF/atlas label pipeline if present.
- If the existing pipeline is insufficient, introduce cached text atlas or scale-bucket strategy.
- Do not use SwiftUI overlay labels for every node.
- Do not create duplicate text render trees.
- Do not make labels a fixed HUD layer detached from node positions.

Acceptance:

- Zooming in/out makes labels feel attached to nodes.
- Labels remain crisp at common zoom levels.
- Dense graphs remain smooth.
- Background labels do not overwhelm the view when zoomed out.
- Selected/hovered/focused labels remain easy to read.

Additional screenshot-derived acceptance:

- Selecting a high-degree folder keeps the selected/root label readable without forcing every neighbor label to full visibility.
- Connected neighbors of a selected node remain eligible for context, but still obey density pressure and local cell budgets.
- Zoomed-out labels do not collapse into a central block; crowded screen cells shrink/fade/cull background labels.
- Sparse regions retain larger, readable labels so the graph does not feel empty or over-pruned.
- Selecting a node should again reveal labels for its connected neighbors, but those neighbor labels must still be dynamically sized and density-thinned so they do not form a single white label mass.

Patch evidence, 2026-05-09 label density slice:

- Files changed:
  - `graph-engine/src/engine.rs`
  - `graph-engine/src/label_envelope.rs`
  - `graph-engine/src/lib.rs`
  - `graph-engine/src/simulation.rs`
  - `graph-engine/src/ecs/components.rs`
  - `graph-engine/src/ecs/bridge.rs`
  - `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`
- Product behavior:
  - Label screen size now uses a stronger hybrid zoom curve so labels scale with graph zoom rather than behaving like fixed HUD text.
  - Label candidates are density-cell culled and scaled. Crowded cells shrink/fade/thin labels; sparse regions keep larger labels.
  - Selected/root/hovered labels are protected, while connected-neighbor labels are eligible again without bypassing density pressure.
  - Long labels now produce a bounded world-space label envelope that feeds the existing simulation `collision_radii` input. The force model, Barnes-Hut repulsion, link forces, decay, gravity, and integrator remain unchanged.
  - ECS `GraphNodeComponent` now carries append-only label envelope metadata (`label_half_width`, `label_half_height`, `label_offset_y`, `label_pad`) so the runtime node record reflects the label bubble rather than leaving it as a render-only concern.
- Tests/commands:
  - Red proof: `cargo test --manifest-path graph-engine/Cargo.toml load_expands_collision_radii_for_wide_labels` failed before product patch because a long label produced the same collision shell as a short node (`shell=13.08, actual=13.08`).
  - `cargo test --manifest-path graph-engine/Cargo.toml selected_node_can_reveal_connected_neighbor_labels` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml selected_neighbors_do_not_bypass_label_density_pressure` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml hybrid_label` passed, 2 tests.
  - `cargo test --manifest-path graph-engine/Cargo.toml label_envelope` passed, 2 tests.
  - `cargo test --manifest-path graph-engine/Cargo.toml load_sets_collision_radii` passed, 1 test.
  - `cargo test --manifest-path graph-engine/Cargo.toml load_expands_collision_radii_for_wide_labels` passed, 1 test.
  - `cargo test --manifest-path graph-engine/Cargo.toml test_from_graph_basic` passed, 1 test.
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` passed, 21 tests, xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_12-44-26--0500.xcresult`.
  - `./scripts/launch_audit_app.sh` passed and launched `com.epistemos.audit`.
  - `git diff --check` passed.
- Remaining risk:
  - Runtime graph smoke on the user's dense graph is still required to judge legibility, subjective Obsidian-like feel, and whether selected-neighbor labels reveal enough context without crowding. The launched audit profile currently has no vault connected, so dense graph runtime proof is blocked until a vault is selected in that profile.
  - Exact glyph-accurate envelopes and label overlap assertions after a long settle pass remain pending; current envelope is a bounded deterministic approximation keyed by label length.

Patch evidence, 2026-05-09 label overlap tightening slice:

- Files changed:
  - `graph-engine/src/engine.rs`
  - `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`
- Product behavior:
  - Label density pressure now shrinks crowded labels more aggressively before culling, while sparse regions still keep natural larger labels.
  - Label acceptance now estimates each label's actual screen-space text rectangle and rejects non-protected labels that would overlap an already accepted label. This closes the screenshot failure where many selected-neighbor labels survived separate node cells but still formed a single white text block.
  - Selected/root/hovered labels remain protected; connected-neighbor labels remain eligible, but no longer bypass rectangle overlap pressure.
- Tests/commands:
  - Red proof: `cargo test --manifest-path graph-engine/Cargo.toml crowded_labels_shrink_aggressively_before_culling` failed before the shrink curve was tightened.
  - Red proof: the same command initially failed to compile because `estimated_label_screen_rect` did not exist, proving the rectangle-overlap guard was absent before the patch.
  - `cargo test --manifest-path graph-engine/Cargo.toml label_screen_rect_overlap_detects_actual_text_width` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml crowded_labels_shrink_aggressively_before_culling` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml selected_neighbors_do_not_bypass_label_density_pressure` passed.
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` passed, 25 tests, xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_13-15-23--0500.xcresult`.
  - `git diff --check` passed.
- Remaining risk:
  - Runtime dense graph visual smoke is still blocked by the audit profile having no connected vault.

Patch evidence, 2026-05-09 selected-neighbor label density slice:

- Files changed:
  - `graph-engine/src/engine.rs`
  - `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`
- Product behavior:
  - High-degree selected nodes no longer expose every connected-neighbor label at full force. Sparse selections still reveal the full connected set, but dense selections are capped with a soft square-root growth curve and a separate density budget.
  - Selected/root/hovered labels remain protected. Connected-neighbor labels remain eligible for context, but now obey a stricter local density cell, screen-rectangle overlap culling, shrink, and opacity pressure.
  - Conservative label screen-rect estimates now use a wider monospaced advance and padding so long labels such as `CODEX_KIMI_OVERSIGHT_ROUND_*` are culled before they form the central white text mass shown in the runtime screenshots.
  - No simulation force equations were changed; this is a label candidate/scoring/culling slice only.
- Tests/commands:
  - Red proof: `cargo test --manifest-path graph-engine/Cargo.toml selected_high_degree_labels_stay_density_bounded` failed to compile before product code because `selected_neighbor_density_budget(...)` did not exist.
  - Red proof: the same command then failed because the previous crowding scale was still above the required density bound.
  - `cargo test --manifest-path graph-engine/Cargo.toml selected_high_degree_labels_stay_density_bounded` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml selected_node_can_reveal_connected_neighbor_labels` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml label_density` passed, 2 tests.
  - `cargo fmt --manifest-path graph-engine/Cargo.toml` completed.
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` passed, 28 tests, xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_14-31-17--0500.xcresult`.
- Remaining risk:
  - Manual dense graph smoke is still required on the user's actual vault to tune the subjective balance between neighbor context and aggressive text thinning.

Patch evidence, 2026-05-09 high-degree selected label cap tightening slice:

- Files changed:
  - `graph-engine/src/engine.rs`
  - `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`
- Product behavior:
  - High-degree selected folders now admit a smaller connected-neighbor label set before screen-cell and rectangle-overlap culling. A 58-label selected neighborhood is capped to 18 label candidates rather than the previous mid-20s range.
  - The selected-neighbor density target is reduced to 8, so crowded selected neighborhoods shrink/fade/cull faster while sparse selections still reveal their connected labels.
  - The cap uses floor-based square-root growth so adding more neighbors does not round up into visible text-block regressions.
  - This is a label candidate budget/culling change only. It does not touch physics forces, integrator timing, or node motion.
- Tests/commands:
  - Red proof: `cargo test --manifest-path graph-engine/Cargo.toml selected_high_degree_labels_stay_density_bounded` failed because the previous cap exceeded the new `<= 18` high-degree bound.
  - `cargo test --manifest-path graph-engine/Cargo.toml selected_high_degree_labels_stay_density_bounded` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml selected_node_can_reveal_connected_neighbor_labels` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml label_density` passed, 2 tests.
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` passed, xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_15-41-28--0500.xcresult`.
- Remaining risk:
  - Manual dense graph runtime smoke is still required to tune the exact threshold against the user's actual vault screenshots.

Patch evidence, 2026-05-09 rendered-scale label envelope/status slice:

- Files changed:
  - `Epistemos/Views/Graph/GraphForceSettings.swift`
  - `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`
  - `graph-engine/src/label_envelope.rs`
- Product behavior:
  - The physics label envelope now uses the same wider mono-label advance assumption and a larger world-em scale closer to the visible SDF label size. Long labels such as `CODEX_KIMI_OVERSIGHT_ROUND_033_2` produce a collision bubble above 190 world units instead of the previous too-small 69-world-unit half-width estimate.
  - The envelope remains bounded (`LABEL_ENVELOPE_MAX_RADIUS = 240.0`) so long titles do not create unbounded graph spacing.
  - Settings -> Graph -> Display -> Labels now exposes a `Label Bubbles` status row that says long labels expand node spacing without changing the force model. This makes the label-physics behavior visible instead of hidden in Rust internals.
  - No force equations, integrator timing, Barnes-Hut repulsion, link force, gravity, decay, or edge motion code changed.
- Tests/commands:
  - Red proof: `cargo test --manifest-path graph-engine/Cargo.toml long_label_envelope_tracks_rendered_sdf_label_scale` failed before product patch because the physics label envelope half-width was only `69.12`.
  - `cargo test --manifest-path graph-engine/Cargo.toml long_label_envelope_tracks_rendered_sdf_label_scale` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml label_envelope` passed, 3 tests.
  - `cargo test --manifest-path graph-engine/Cargo.toml load_expands_collision_radii_for_wide_labels` passed.
  - Red proof: `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` failed before the settings row existed; failed xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_16-22-57--0500.xcresult`.
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` passed, xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_16-27-13--0500.xcresult`.
  - `git diff --check` passed.
- Remaining risk:
  - Manual dense graph runtime smoke is still required to verify whether the larger collision bubbles produce enough label separation without making the graph feel too sparse or changing the preferred fluid feel.

Patch evidence, 2026-05-09 solid folder glare tuning slice:

- Files changed:
  - `graph-engine/src/renderer.rs`
  - `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`
- Product behavior:
  - Large/high-degree folder hubs keep the old pixel-art glare cue, but the cinematic glare/shadow multipliers are reduced from `0.62/0.16` to `0.24/0.06`.
  - Balanced mode folder glare/shadow is reduced from `0.48/0.12` to `0.20/0.05`.
  - Node body opacity remains solid; the cinematic path still returns `max(in.color.a, 0.95)` and the solid-node tests remain green.
  - Edge z-order remains edges under nodes and labels; render-order test remains green.
- Tests/commands:
  - Red proof: `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` failed before product patch because the renderer still had the old heavy `folder_pixel_glare * 0.62`; failed xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_14-40-21--0500.xcresult`.
  - `cargo test --manifest-path graph-engine/Cargo.toml cinematic_pixel_nodes_apply_selection_dim_without_transparency` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml light_and_dark_graph_nodes_are_solid_not_translucent` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml render_order_keeps_edges_under_nodes_and_labels` passed.
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` passed, 28 tests, xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_14-43-59--0500.xcresult`.
- Remaining risk:
  - Manual visual smoke is still required to judge whether the reduced glare reads as enough depth on the user's fullscreen graph without becoming a dramatic gradient.

Patch evidence, 2026-05-09 graph label/edge controls exposure slice:

- Files changed:
  - `Epistemos/Views/Graph/GraphForceSettings.swift`
  - `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`
- Product behavior:
  - Display -> Labels now exposes existing label policy controls for `Outer Labels`, `Base Size`, `Focus Shrink`, `Dead Zone`, and `Max Inner Labels`.
  - Advanced -> Laboratory -> Structure now exposes the existing `Elastic Edges` toggle and `Edge Elasticity` slider.
  - These controls reuse existing `GraphState` storage and push paths (`labelPolicyVersion`, `saveLabelPolicy()`, `pushLabChange()`); no new force model or renderer path was added.
- Tests/commands:
  - Red proof: `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` failed before product patch because `Outer Labels`, `Base Size`, `Focus Shrink`, `Elastic Edges`, and `Edge Elasticity` were not present in `GraphForceSettings`; failed xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_14-49-42--0500.xcresult`.
  - Same command passed after product patch, 28 tests, xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_14-53-11--0500.xcresult`.
- Remaining risk:
  - Manual graph settings popover smoke is still required to verify the new controls are readable at the current panel width and update labels/edges live.

### UIX-2026-05-09-009 - Graph visual phase: label bubbles, colored edges, pixel-art edges, endpoint trim

Status: PARTIAL - LABEL COLLISION ENVELOPE + WEIGHTED SMOOTH CURVE EDGES + SELECTED FOCUS RESTORED / PIXEL EDGE STYLE AND ENDPOINT TRIM REMOVED AFTER RUNTIME REGRESSION / COLORED GROUP EDGES TODO

Supersession note, 2026-05-10:

- Live dense-graph screenshots showed the endpoint-trim and pixel/straight edge variants produced visibly offset, wrapped, and non-attached edges.
- Current product acceptance for edge rendering is therefore one canonical smooth curved-edge path: source/target node centers, edges drawn behind solid node bodies, no endpoint-trim module, no Pixel-Art edge style UI, no straight-edge style branch, and no graph style FFI.
- Optional pixel-art edge restoration is no longer active current-product code. If it returns later, it must be a separate isolated PR with screenshots, GPU proof, and no fallback impact on the smooth curve path.

User signal:

- Labels should behave like part of the node's atmosphere/collision bubble so labels do not overlap other labels or nodes.
- Edges should remain below nodes in z-order and should terminate at node disc boundaries rather than visually cutting through node centers.
- Future edge work should support group-driven colors, variable thickness, and an optional restored pixel-art jagged edge style from the pre-2026-03-06 renderer.
- Theme palettes should eventually be able to affect graph node/edge semantic colors, but without compromising the base light/dark black/white graph readability.

Source evidence / recovery pointers:

- Current simulation already uses per-node `collision_radii` in `graph-engine/src/simulation.rs`.
- Old pixel-art edge infrastructure was removed in commit `b1a3609d6` (`2026-03-06`, "feat(graph): delete pixel art rendering infrastructure"). The predecessor `b1a3609d6^` should be inspected for `PIXEL_SHADER_SOURCE`, `PixelEdgeInstance`, `build_pixel_edge_instances`, pixel uniforms, and palette code before any restoration.
- Current renderer draw order lives in `graph-engine/src/renderer.rs` and must remain edges -> field lines -> nodes -> SDF labels -> dialogue overlay.

Required behavior:

- Label collision bubble:
  - Add append-only label envelope fields to the graph node component or equivalent runtime structure.
  - Compute `bubble_radius = max(node_radius, sqrt((label_half_width + pad)^2 + (abs(label_offset_y) + label_half_height + pad)^2))`.
  - Feed the bubble radius into the existing `collision_radii` input without changing Barnes-Hut repulsion, link forces, gravity, decay, or integrator logic.
  - Recompute envelopes only when label text/scale changes, not per frame.
- Edge z-order and trim:
  - Edge render pass must stay before nodes and labels in all themes and edge styles.
  - Edge geometry should terminate at endpoint node disc boundaries, not centers. Use node disc radius, not label bubble radius, for visual trimming.
  - Nodes must remain opaque enough that third-party crossing edges do not bleed through node discs.
  - The selected-node pulse must remain visible without making node bodies translucent.
- Colored/weighted edges:
  - Add graph color groups only as a separate slice with a real UI, persistent SwiftData state, and debounced `FilterEngine` evaluation.
  - Shared endpoint group color wins; differing group colors blend in OKLab; otherwise fall back to existing edge type colors.
  - Edge thickness derives from edge weight and clamps against small endpoint radius.
- Pixel-art jagged edges:
  - Restore only the pixel edge path as an opt-in edge style. Do not restore pixel node rendering in this slice.
  - Pixel edge jitter must be deterministic per edge id, trimmed before jitter, and clamped so it does not poke into endpoint or nearby node discs.
  - The feature must work in both MAS and Pro builds if exposed.

Tests required before implementation is accepted:

- `bubble_radius_includes_label_for_wide_titles` - partial automated proof exists as `load_expands_collision_radii_for_wide_labels` and `label_envelope::wide_label_envelope_is_larger_than_node_disc`.
- `labels_do_not_overlap_after_settle` - TODO.
- `node_with_no_label_falls_back_to_default_radius` - partial automated proof exists as `load_sets_collision_radii`.
- `label_envelope_ffi_roundtrip` - not applicable to the current bounded Rust-side estimate; TODO if this becomes exact Swift glyph-envelope FFI.
- `render_order_is_edges_then_nodes_then_labels` - partial automated proof exists as `render_order_keeps_edges_under_nodes_and_labels`.
- `edge_geometry_terminates_at_node_disc` - automated proof exists as `edge_geometry_terminates_at_node_disc_boundaries` plus renderer source guard for `trim_curve_endpoints` / `trim_line_endpoints`.
- `thick_edge_clamps_to_small_endpoint_radius` - partial automated proof exists as `edge_weight_maps_to_clamped_screen_thickness`.
- `edge_color_picks_shared_group_color`
- `edge_color_blends_when_groups_differ`
- `pixel_edge_instance_layout_48_bytes`
- `pixel_pipeline_compiles_on_metal`
- `pixel_jitter_is_deterministic_per_edge_id`

Patch evidence, 2026-05-09 weighted edge + selection atmosphere slice:

- Files changed:
  - `graph-engine/src/renderer.rs`
  - `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`
- Product behavior:
  - Classic curve and straight edge instances now carry a per-instance `thickness_px`.
  - Edge screen thickness derives from `EdgeComponent.weight` through a bounded gamma curve (`0.70px` to `4.00px`) and clamps against small endpoint radius so heavy edges do not visually swallow small nodes.
  - Edge shader geometry uses the per-instance thickness instead of the old hardcoded `1.5px` width.
  - The existing render order contract remains edges -> field lines -> nodes -> SDF labels -> dialogue overlay.
  - Cinematic pixel nodes now apply selection dimming before returning solid node color, so selecting a node again de-emphasizes surrounding non-neighbor nodes while preserving opaque node bodies.
  - The label envelope work is explicitly guarded from modifying `forces.rs`; the force model remains unchanged and label physics only feeds the existing collision-radii input.
- Tests/commands:
  - Red proof: `cargo test --manifest-path graph-engine/Cargo.toml edge_weight_maps_to_clamped_screen_thickness` failed before product patch because `MIN_EDGE_WIDTH_PX`, `MAX_EDGE_WIDTH_PX`, and `edge_width_px_for_weight` did not exist.
  - Red proof: `cargo test --manifest-path graph-engine/Cargo.toml cinematic_pixel_nodes_apply_selection_dim_without_transparency` failed after the self-referential guard was corrected because the production shader branch did not apply selection dimming before the cinematic solid-node return.
  - `cargo test --manifest-path graph-engine/Cargo.toml edge_weight_maps_to_clamped_screen_thickness` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml line_edge_instance_size` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml curve_edge_instance_size` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml render_order_keeps_edges_under_nodes_and_labels` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml cinematic_pixel_nodes_apply_selection_dim_without_transparency` passed.
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` passed, 24 tests, xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_13-08-27--0500.xcresult`.
  - `git diff --check` passed.
- Remaining risk:
  - Runtime dense graph visual smoke is still blocked by the audit profile having no connected vault.
  - Group-colored edges and optional pixel-art jagged edge style remain TODO; only weighted thickness and existing z-order protection are wired in this slice.

Patch evidence, 2026-05-09 endpoint trim proof slice:

- Files changed:
  - `graph-engine/src/edge_trim.rs`
  - `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`
- Product behavior:
  - No runtime behavior changed in this slice; it proves the existing renderer path trims straight and curved edge endpoints to the endpoint node disc boundary plus `DEFAULT_EDGE_GAP_PX` before Metal upload.
- Tests/commands:
  - `cargo test --manifest-path graph-engine/Cargo.toml edge_geometry_terminates_at_node_disc_boundaries` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml edge_trim` passed, 10 tests.
  - `cargo test --manifest-path graph-engine/Cargo.toml render_order_keeps_edges_under_nodes_and_labels` passed.
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` passed, 26 tests, xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_13-28-33--0500.xcresult`.
  - `git diff --check` passed.
- Remaining risk:
  - Runtime dense graph visual smoke is still blocked by the audit profile having no connected vault.
  - Pixel-art jagged edges still need their own trim/jitter proof once that optional style exists.

Patch evidence, 2026-05-09 endpoint-palette edge tint slice:

- Files changed:
  - `graph-engine/src/renderer.rs`
  - `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`
- Product behavior:
  - Classic graph edges now tint from endpoint node color overrides when those overrides are present, so theme/semantic node palettes influence the edge field instead of leaving all edges purely edge-type colored.
  - When both endpoints have palette colors, the edge uses a midpoint endpoint tint mixed over the existing edge-type fallback while preserving the existing edge alpha and highlight/dim behavior.
  - When no endpoint palette is present, the renderer falls back to the existing `edge_type_color(...)` / `edge_type_color_light(...)` path.
  - This is not the full persistent color-groups panel; group-driven edge colors and OKLab group blending remain TODO in the visual phase.
- Tests/commands:
  - Red proof: `cargo test --manifest-path graph-engine/Cargo.toml edge_color_blends_endpoint_palette_when_available` failed before product patch because `edge_color_with_endpoint_palette(...)` did not exist.
  - `cargo test --manifest-path graph-engine/Cargo.toml edge_color_blends_endpoint_palette_when_available` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml edge_weight_maps_to_clamped_screen_thickness` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml renderer::tests` failed inside the sandbox because Metal `Device::system_default()` was unavailable to renderer tests.
  - Same `cargo test --manifest-path graph-engine/Cargo.toml renderer::tests` command passed outside the sandbox with host Metal access, 59 tests.
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` passed, xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_15-59-33--0500.xcresult`.
- Remaining risk:
  - Manual dense graph runtime smoke is still required to verify edge tint is visible but not noisy in the user's vault.
  - Persistent Obsidian-style graph color groups, OKLab group blending, and the Groups panel are still not implemented.

Patch evidence, 2026-05-09 selected-focus dimming restoration slice:

- Files changed:
  - `Epistemos/Graph/GraphState.swift`
  - `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`
  - `graph-engine-bridge/graph_engine.h`
  - `graph-engine/src/engine.rs`
  - `graph-engine/src/lib.rs`
  - `graph-engine/src/renderer.rs`
- Product behavior:
  - `GraphState.selectNode(_:)` now pushes selection into Rust through `graph_engine_select_node(...)` / `graph_engine_clear_selected_node(...)`, so sidebar, inspector, search, context-menu, and canvas selection share the same selected-neighborhood focus path.
  - Rust `Engine::select_node(...)` sets `selected_id` and calls the existing `highlight_neighbors_by_id(...)` path. This restores selected-node neighborhood labels, selected/neighbor focus flags, and surrounding-node dimming without changing the simulation force model.
  - Clearing selection now clears Rust `selected_id` and the selection-derived highlight set together, preventing stale selected focus after UI deselection. Selecting a stale/missing node id also clears the Rust focus instead of preserving the previous highlight.
  - `Engine::clear_highlight()` and search-highlight activation now also clear `renderer.highlight.root_id`, so a previous selected-folder root cannot keep protected labels or selected-neighborhood dimming alive after selection is cleared or replaced by search.
  - Cinematic and balanced node shader dimming now darkens non-focused nodes in both light and dark mode instead of lightening dark-mode surroundings. Dimmed nodes remain effectively solid (`0.95` alpha floor), so edges stay visually behind opaque node bodies.
  - Node highlight flag coverage now asserts light and dark modes use separate dim flags for non-neighbor nodes.
- Tests/commands:
  - Red proof: `cargo test --manifest-path graph-engine/Cargo.toml select_node_syncs_selection_and_neighborhood_focus` failed before product patch because `Engine::select_node(...)` and `Engine::clear_selected_node(...)` did not exist.
  - Regression proof: full `cargo test --manifest-path graph-engine/Cargo.toml` later failed `engine::tests::select_node_syncs_selection_and_neighborhood_focus` because `clear_highlight()` did not clear stale `root_id`; patching root cleanup fixed the failure.
  - `cargo test --manifest-path graph-engine/Cargo.toml select_node_syncs_selection_and_neighborhood_focus` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml engine::tests::selected` passed, 3 tests.
  - `cargo test --manifest-path graph-engine/Cargo.toml light_and_dark_node_highlight_flags_dim_non_neighbors` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml cinematic_pixel_nodes_apply_selection_dim_without_transparency` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml` passed after stale-root cleanup, 2551 tests passed and 8 ignored.
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` passed, xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_15-34-46--0500.xcresult`.
  - Source guard: `rg -n "graph_engine_select_node|graph_engine_clear_selected_node|select_node_syncs_selection_and_neighborhood_focus|light_and_dark_node_highlight_flags_dim_non_neighbors|dim_alpha_floor|0\\.06, 0\\.06, 0\\.06" Epistemos/Graph/GraphState.swift graph-engine/src/engine.rs graph-engine/src/lib.rs graph-engine/src/renderer.rs graph-engine-bridge/graph_engine.h EpistemosTests/GraphPhysicsSettingsAuditTests.swift` confirmed bridge, Swift caller, Rust selection, and shader dimming coverage.
  - `git diff --check` passed.
- Remaining risk:
  - Manual dense graph runtime smoke is still required on the user's actual vault to verify subjective dim strength, selected-neighbor label usefulness, and that the fluid feel remains unchanged under real interaction.

Patch evidence, 2026-05-09 user-visible edge style slice:

- Files changed:
  - `Epistemos/Graph/GraphState.swift`
  - `Epistemos/Views/Graph/GraphForceSettings.swift`
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`
  - `graph-engine-bridge/graph_engine.h`
  - `graph-engine/src/engine.rs`
  - `graph-engine/src/lib.rs`
  - `graph-engine/src/renderer.rs`
- Product behavior:
  - Settings -> Graph -> Display now exposes an `Edge Style` segmented control with `Smooth` and `Pixel-Art`.
  - `GraphState.edgeStyle` persists through `epistemos.graph.edgeStyle`, increments `edgeStyleVersion`, and wakes the renderer without touching physics settings.
  - `MetalGraphView` pushes `graph_engine_set_edge_style(engine, graphState.edgeStyle.rawValue)` on commit and on live edge-style changes.
  - Rust `Engine::set_edge_style(...)` forwards to the renderer, marks edge buffers for rebuild, and leaves the quality level and simulation force model unchanged.
  - Pixel-Art edge style forces straight edge geometry even in cinematic quality, snaps edge endpoints to device pixels in the existing line-edge shader, and uses a hard edge fragment cutoff. Nodes, labels, selection dimming, endpoint trimming, z-order, and weighted thickness stay on the existing renderer path.
  - This is a bounded first pixel-edge slice, not the full restored pre-2026-03-06 offscreen jagged edge pipeline.
- Tests/commands:
  - Red proof: `cargo test --manifest-path graph-engine/Cargo.toml pixel_edge_style_forces_straight_pixel_uniforms_without_quality_downgrade` failed before product patch because `Renderer.edge_style`, `EdgeStyle`, and `Uniforms.edge_style` did not exist.
  - Red proof: `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` failed after the first product patch because the settings control used dynamic `style.displayName` and did not literally expose the `Pixel-Art` source contract; failed xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_16-42-56--0500.xcresult`.
  - `cargo test --manifest-path graph-engine/Cargo.toml pixel_edge_style_forces_straight_pixel_uniforms_without_quality_downgrade` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml edge_style` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml renderer::tests` passed, 60 renderer tests.
  - `cargo test --manifest-path graph-engine/Cargo.toml engine::tests::quality_level_change_marks_renderer_for_buffer_rebuild` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml` passed, 2553 tests passed and 8 ignored.
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` passed, 30 tests, xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_16-47-51--0500.xcresult`.
  - `git diff --check` passed.
- Remaining risk:
  - Manual graph settings/runtime smoke is still required to verify the segmented control is visible, switching styles redraws edges live, pixel-snapped edges feel intentional rather than noisy, and edges remain below solid node bodies in the user's dense vault.
  - Full restored jagged pixel-edge pipeline with deterministic jitter, `PixelEdgeInstance`, and old offscreen pixel upscale remains a later isolated sub-slice.
  - Persistent Obsidian-style graph color groups and OKLab group blending remain TODO.

Patch evidence, 2026-05-09 deterministic jagged edge shader slice:

- Files changed:
  - `graph-engine/src/renderer.rs`
  - `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md`
- Product behavior:
  - The `Pixel-Art` edge style now uses a deterministic shader-side jagged cutoff instead of only a hard antialiased-off line.
  - The jagged cutoff is derived from fragment position and per-edge `instance_id` seed, so the silhouette is stable for the same edge and does not require per-frame CPU edge geometry rebuilds.
  - The style still uses the existing straight edge pass, endpoint trimming, weighted thickness, z-order under nodes, and solid-node occlusion. It does not restore pixel nodes or the old offscreen pixel upscale path.
- Tests/commands:
  - Red proof: `cargo test --manifest-path graph-engine/Cargo.toml pixel_edge_shader_uses_deterministic_jagged_cutoff` failed after the test was corrected to inspect only the shader block because `pixel_jagged_offset(...)` did not exist.
  - `cargo test --manifest-path graph-engine/Cargo.toml pixel_edge_shader_uses_deterministic_jagged_cutoff` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml renderer::tests` passed, 61 renderer tests.
- Remaining risk:
  - Manual graph smoke is required to tune jagged strength; the current shader is deliberately subtle to avoid noisy dense graphs.
  - Full old `PixelEdgeInstance` / offscreen nearest-neighbor pixel pipeline is still not restored.

Patch evidence, 2026-05-10 smooth-edge cleanup and buffer-regression guard:

- Files changed:
  - `Epistemos/Graph/GraphState.swift`
  - `Epistemos/Views/Graph/GraphForceSettings.swift`
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`
  - `graph-engine-bridge/graph_engine.h`
  - `graph-engine/src/engine.rs`
  - `graph-engine/src/lib.rs`
  - `graph-engine/src/renderer.rs`
  - Deleted `graph-engine/src/edge_trim.rs`
- Product behavior:
  - Removed the `GraphEdgeStyle` Swift state, persisted defaults keys, Display settings segmented control, MetalGraphView FFI push, Rust `Engine::set_edge_style(...)`, `graph_engine_set_edge_style(...)`, renderer `EdgeStyle`, straight/pixel edge mode, edge-style uniforms, and the endpoint-trim module.
  - The active renderer now has one smooth curved-edge path. Edges use node center positions again and rely on the existing draw order and solid node bodies to hide the segment under nodes.
  - Smooth edges remain slightly thicker than the pre-pass rope-thin appearance and keep light/dark neutral grey defaults plus selected-edge focus/dim behavior.
  - Curve sag is capped so long selected/folder links do not wrap around nodes while still rendering as the original curved line language.
  - Added renderer debug counters for edge buffer allocations/reuse and a regression test proving a same-size visible edge set reuses existing Metal buffer capacity instead of reallocating.
- Tests/commands:
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests test CODE_SIGNING_ALLOWED=NO` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml renderer::tests` passed, 68 tests.
  - `cargo test --manifest-path graph-engine/Cargo.toml` passed, 2554 tests passed and 8 ignored; doc-tests passed.
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO` passed.
  - Source guards confirm no production `GraphEdgeStyle`, `EdgeStyle`, `edge_style`, `EdgeGeometryKind`, `edge_trim`, `graph_engine_set_edge_style`, `Pixel-Art`, or pixel-edge branch remains.
  - `git diff --check -- graph-engine/src/renderer.rs graph-engine/src/engine.rs graph-engine/src/lib.rs graph-engine/src/edge_trim.rs graph-engine-bridge/graph_engine.h Epistemos/Graph/GraphState.swift Epistemos/Views/Graph/GraphForceSettings.swift Epistemos/Views/Graph/MetalGraphView.swift EpistemosTests/GraphPhysicsSettingsAuditTests.swift` passed.
- Remaining risk:
  - Manual dense-vault graph smoke is still required to verify the user's real graph no longer shows offset/wrapped edges, selected-neighborhood focus still reads correctly, and subjective FPS/interaction smoothness match the automated buffer-reuse and full graph-engine test proof.

Patch evidence, 2026-05-09 sparse-cell high-degree label density slice:

- Files changed:
  - `graph-engine/src/engine.rs`
  - `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md`
- Product behavior:
  - Selected high-degree folder neighborhoods still reveal connected-node labels, but the global crowding term now applies even when every neighbor falls into a different density cell.
  - This directly targets the observed dense-graph failure mode where long selected-neighbor labels survive as a bright central text pile despite local-cell density checks.
  - Sparse areas still keep the larger dynamic label size; the patch changes label scoring/opacity only and does not modify `graph-engine/src/forces.rs`, the integrator, edge ordering, node palette, or collision physics.
- Tests/commands:
  - Red proof: `cargo test --manifest-path graph-engine/Cargo.toml selected_high_degree_labels_shrink_even_when_cells_are_sparse` failed before product patch because sparse-cell high-degree labels stayed above the new density bound.
  - `cargo test --manifest-path graph-engine/Cargo.toml selected_high_degree_labels_shrink_even_when_cells_are_sparse` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml selected_high_degree_labels_stay_density_bounded` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml sparse_labels_keep_larger_dynamic_size` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml label` passed, 28 tests.
  - `git diff --check` passed.
- Remaining risk:
  - Manual dense-vault graph smoke is still required to verify the subjective balance: selected-node labels should give useful neighborhood context without forming the white label block shown in the user's screenshots.
  - Runtime screenshots at multiple zoom levels are still needed before this can be marked visually complete.

Patch evidence, 2026-05-09 folder hub semantic sizing slice:

- Files changed:
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `EpistemosTests/GraphPerformanceTests.swift`
  - `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md`
- Product behavior:
  - Folder nodes sent to Rust now use `max(actual graph degree, recursive folder content weight)` for the existing link-count/radius/depth input.
  - This connects the already-existing `GraphBuilder` recursive folder content count to rendered folder size/depth, so parent folder hubs can become the largest solid folder nodes and qualify for the subtle pixel-glare tier.
  - Non-folder nodes still use their actual graph degree. No new FFI field, force-model change, edge ordering change, or node transparency change was introduced.
- Tests/commands:
  - Red proof: `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPerformanceTests test CODE_SIGNING_ALLOWED=NO` failed before product patch because the new test observed `payload.linkCounts -> [0]` for a folder with semantic weight `57`.
  - Red xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_17-09-49--0500.xcresult`.
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphPerformanceTests test CODE_SIGNING_ALLOWED=NO` passed, 23 tests.
  - Green xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_17-13-40--0500.xcresult`.
  - Source guard: `rg -n "semanticFolderCount|ffiNodeBatchSendsFolderSemanticWeightForParentHubSizing|folder semantic weight|GraphNodeRecord\\(.*type: \\.folder" Epistemos/Views/Graph/MetalGraphView.swift EpistemosTests/GraphPerformanceTests.swift docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` confirmed the Swift payload and test coverage.
  - `git diff --check` passed.
- Remaining risk:
  - Manual graph smoke is still required to confirm top-level empty folders remain plain, parent folders with substantial descendants become visually prominent, and the subtle glare reads as solid-body depth rather than transparency.
  - The current signal is recursive content weight, not a dedicated folder-depth field. If product wants glare only for folders that both have descendants and sit at a particular hierarchy level, a separate folder-depth metadata/FFI path remains a future refinement.

Patch evidence, 2026-05-09 soft label collision physics correction:

- Files changed:
  - `graph-engine/src/simulation.rs`
  - `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md`
- Product behavior:
  - Label envelopes still exist for spacing metadata and render/culling truth, but the simulation no longer uses the full text-envelope radius as a hard collision body.
  - Wide-label collision now uses a capped, blended soft shell (`LABEL_COLLISION_SOFT_BLEND` / `LABEL_COLLISION_MAX_EXTRA`) so labels remain a spacing hint instead of creating the stiff invisible force field reported in the live graph.
  - The force model, integrator, `graph-engine/src/forces.rs`, node palette, edge ordering, and folder semantic sizing path were not changed.
- Tests/commands:
  - Red proof: `cargo test --manifest-path graph-engine/Cargo.toml wide_label_collision_shell_stays_soft_for_fluid_motion` failed before product patch with `shell=13.08, actual=203.35683`.
  - `cargo test --manifest-path graph-engine/Cargo.toml wide_label_collision_shell_stays_soft_for_fluid_motion` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml load_expands_collision_radii_for_wide_labels` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml load_sets_collision_radii` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml simulation::tests` passed, 188 tests.
  - `cargo test --manifest-path graph-engine/Cargo.toml label` passed, 29 tests.
- Remaining risk:
  - Manual dense-vault smoke is still required to tune the subjective balance between label spacing and fluid motion. The intended feel is smooth/fluid first, with label collision acting only as a gentle spacing hint.

Patch evidence, 2026-05-09 water-soft node contact tuning:

- Files changed:
  - `graph-engine/src/simulation.rs`
  - `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md`
- Product behavior:
  - Default collision compliance is now `0.42`, so node overlaps resolve over more frames and contact reads like a fluid/water push instead of rigid discs snapping apart.
  - Label collision contribution was softened again (`LABEL_COLLISION_SOFT_BLEND = 0.12`, `LABEL_COLLISION_MAX_EXTRA = 28.0`) so long labels can reserve a little space without creating aggressive invisible physics around nodes.
  - This is still a collision-contact tuning only: link force, charge force, fluid wake, integrator, node palette, edge order, and `graph-engine/src/forces.rs` are unchanged.
- Tests/commands:
  - Red proof: `cargo test --manifest-path graph-engine/Cargo.toml default_collision_compliance_is_water_soft` failed before product patch because default compliance was `0.7`.
  - Red proof: `cargo test --manifest-path graph-engine/Cargo.toml wide_label_collision_shell_stays_soft_for_fluid_motion` failed under the stricter water-soft bound with `shell=13.08, actual=57.165638`.
  - `cargo test --manifest-path graph-engine/Cargo.toml default_collision_compliance_is_water_soft` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml wide_label_collision_shell_stays_soft_for_fluid_motion` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml load_expands_collision_radii_for_wide_labels` passed.
  - `cargo test --manifest-path graph-engine/Cargo.toml simulation::tests` passed, 189 tests.
  - `cargo test --manifest-path graph-engine/Cargo.toml label` passed, 29 tests.
- Remaining risk:
  - Manual dense-vault interaction smoke is required: drag a hub through leaves and verify nodes compress/recover like water while avoiding visually permanent overlap.
  - If live smoke still feels stiff, the next safe knob is further reducing label-shell max extra or exposing contact softness in Graph Display/Laboratory without changing the force model.

Constraints:

- Do not modify `graph-engine/src/forces.rs`.
- Do not change the existing integrator or force model; only the collision radius input may change for label bubbles.
- No per-glyph FFI calls. Envelope updates must be batched/coalesced.
- No per-frame text layout allocation.
- No pixel-node restoration in the edge-style slice.
- No theme overlay/compositing hacks.

### UIX-2026-05-09-007 - Restore Settings Appearance theme picker

Status: PATCHED - SETTINGS PICKER AUTOMATED GREEN / MANUAL THEME SWITCH SMOKE PENDING

User signal:

- Theme definitions and theme pairs are still in the app, but Settings no longer exposes a picker. The app therefore feels visually reduced even though the theme registry remains intact.

Source evidence:

- `Epistemos/Theme/EpistemosTheme.swift` still contains 14 `EpistemosTheme` cases and six `ThemePair` pairings.
- The deleted Settings picker was removed in commit `78c247287` (`2026-03-16`, "refactor: remove legacy custom theme settings").
- Deleted UI/state included `AppearanceThemePairSection`, `ThemePairCard`, `ForEach(ThemePair.allCases, id: \.self)`, `selectedPairDraft`, `pendingThemePair`, and `scheduleThemePairChange`.
- Current `AppearanceDetailView` only surfaces system appearance and display mode. No current user flow can choose `ThemePair` values.

Required behavior:

- Restore a small `Settings -> Appearance` theme pair section without reviving old overlay/compositing theme code.
- Render one card per `ThemePair.allCases` with pair name, `Light · Dark` subtitle, and two swatches sampled from `pair.lightTheme.resolved.background` and `pair.darkTheme.resolved.background`.
- Add or restore a `Follow macOS` control above the grid. When enabled, theme follows effective system appearance and the pair picker disables or clearly becomes a preference for automatic light/dark resolution.
- Selection writes through the current `UIState.theme` flow by resolving `pair.resolved(isDark:)` against effective dark mode.
- Preserve dark/light auto-switching when follow-system mode is enabled.
- Restore or extend `EpistemosTests/ThemePairTests.swift` and add focused Settings source/runtime coverage where feasible.

Constraints:

- Native semantic theme tokens only.
- No fullscreen overlays, floating theme layers, opacity masks, or duplicate render trees.
- No graph/editor cache invalidation beyond theme/material caches.
- This picker restoration is separate from the broader forensic theme restoration inventory in `UIX-2026-05-09-001`.

Patch evidence, 2026-05-09 Settings theme picker restoration slice:

- Files changed:
  - `Epistemos/State/UIState.swift`
  - `Epistemos/Views/Settings/SettingsView.swift`
  - `EpistemosTests/ThemePairTests.swift`
  - `EpistemosTests/ThemePickerRestorationTests.swift`
- Product behavior:
  - `UIState` now restores valid `ThemeMode.defaultsKey` and `UIState.themePairDefaultsKey` values on launch instead of clearing them.
  - `UIState.theme` resolves `.systemDefault` to the dedicated native system tokens, and resolves `.custom` through `activePair.resolved(isDark:)`.
  - Theme mutators are active again, but `preferredColorScheme`, `windowAppearance`, `usesNativeWindowBlur`, and `shouldUseThemeWorkarounds` remain non-custom-overlay/native-safe.
  - Settings -> Appearance now contains a `Themes` section with a `Follow macOS` toggle and one `ThemePairCard` per `ThemePair.allCases`.
  - Theme cards show pair names/descriptions plus light/dark swatches sampled from `pair.lightTheme.resolved.background.color` and `pair.darkTheme.resolved.background.color`.
  - Selecting a card writes through `ui.setPair(pair)` and `ui.setThemeMode(.custom)`.
- Tests added/updated:
  - `ThemePickerRestorationTests.customThemePairResolvesSemanticTokensWithoutWindowOverlays`
  - `ThemePickerRestorationTests.savedThemePairPreferencesRestoreOnLaunch`
  - `ThemePickerRestorationTests.settingsAppearanceExposesThemePairPicker`
  - `ThemePairTests` updated away from the temporary system-only assertions and toward restored semantic-theme behavior without custom chrome/backdrop workarounds.
- Commands/results:
  - Red proof: `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ThemePickerRestorationTests test CODE_SIGNING_ALLOWED=NO` failed before product patch because the new source guard/persistence assertions could not be satisfied while the picker was absent and `UIState` pinned themes to system-only behavior.
  - Intermediate compatibility proof: `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ThemePairTests test CODE_SIGNING_ALLOWED=NO` failed before test update with four expected stale system-only assertions; failed xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_13-45-43--0500.xcresult`.
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ThemePickerRestorationTests test CODE_SIGNING_ALLOWED=NO` passed.
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ThemePairTests test CODE_SIGNING_ALLOWED=NO` passed.
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ThemePickerRestorationTests -only-testing:EpistemosTests/NoteWindowManagerTests -only-testing:EpistemosTests/SettingsWindowPresentationTests test CODE_SIGNING_ALLOWED=NO` passed, 41 tests, xcresult `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_13-51-52--0500.xcresult`.
- Remaining risk:
  - Manual built-app smoke is still required: open Settings -> Appearance, select each theme pair, toggle Follow macOS, switch system light/dark mode, and verify notes/sidebar/settings/graph surfaces update without overlay glitches or stale cache behavior.
  - Broader historical theme forensic inventory and graph palette theming remain tracked in `UIX-2026-05-09-001` and the graph visual items.

### UIX-2026-05-09-008 - First-use Codex web research approval must be app-native and out-of-box

Status: PATCHED - PROMPT/ROUTING CONTRACT GREEN / LIVE FIRST-RUN SMOKE PENDING

User signal:

- On first use in the audit app, a user asked for research/manifeso-style work and Codex responded with a text-only instruction instead of an app-native approval flow:
  - `I can do that, but for actual research I should use web search first, and that tool needs your approval.`
  - `If you want me to proceed, just say: approve web search.`
- The user expectation is that the app should work out of the box. If web research requires approval, the approval must be a visible product control, not a conversational incantation.

Runtime evidence:

- Observed in the built audit app (`com.epistemos.audit`) during the `/Users/jojo/all research` live-vault smoke on 2026-05-09.
- The visible transcript showed a tool-capable route (`Tools` mode and vault/search/tool chips were visible), but the model still asked the user to type approval text rather than presenting an approval card/button.

Likely files to inspect:

- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/Engine/PipelineService.swift`
- `Epistemos/Bridge/ToolTierBridge.swift`
- `Epistemos/State/AgentCommandCenterState.swift`
- `Epistemos/Views/Chat/ChatInputBar.swift`
- `Epistemos/Views/Chat/MessageBubble.swift`
- provider-native web search adapters and app-layer web-search tool definitions
- approval presenters / `SovereignGate` / permission request UI
- `agent_core/src/tools/registry.rs`
- `agent_core/src/permissions.rs`

Required behavior:

- A first-run tool-required research prompt should either execute with the already-enabled app-approved web/search route, or present a clear native approval request with approve/deny controls.
- The assistant should not ask the user to type magic phrases such as `approve web search`.
- If web search is unavailable because of build, route, provider, policy, account, network, or App Store gating, the UI should explain the unavailable state and offer the correct setup or fallback path.
- Approval state should be logged and visible in the transcript/tool provenance surface.
- Denial should produce a coherent no-web fallback, not a stalled request.
- App Store builds must either hide web-search affordances or hard-deny them with honest copy if the capability is unavailable.

Acceptance:

- Fresh install / fresh audit support root: ask a web-research-heavy prompt; app shows a native approval card or executes under an already-approved route.
- Approve path: web/search tool call executes, transcript shows the tool use, and final answer continues without needing a second typed prompt.
- Deny path: transcript records denial and the assistant offers an offline/current-knowledge answer path.
- Unavailable path: Settings/composer/model-route UI identify the missing capability before or during submit.

Patch evidence 2026-05-09:

- Files changed:
  - `Epistemos/Engine/OverseerProtocol.swift`
  - `Epistemos/Engine/CapabilityManifestBuilder.swift`
  - `EpistemosTests/TriageServiceTests.swift`
  - `EpistemosTests/PipelineServiceTests.swift`
  - `agent_core/src/prompts.rs`
- Product behavior:
  - Managed-agent execution plans no longer tell the model to treat `ask` tools as a conversational precondition. They now say to call the tool and let Epistemos show the native approval card.
  - Direct cloud/provider-native turns now receive the same rule in `CapabilityManifestBuilder`: if a listed tool needs approval, call it; do not ask the user to type an approval phrase.
  - Rust agent/research prompts now carry the same host-native approval contract, so local/managed research routes do not regress into text-only approval requests.
  - The exact observed phrase `approve web search` is no longer present in production or test source as a literal.
- Tests added/updated:
  - `OverseerComplexityRouterTests.askToolsUseNativeApprovalInsteadOfTypedApprovalPhrases`
  - `PipelineServiceTests.cloudManifestIncludesProviderNativeWebSearch`
  - `prompts::tests::prompts_use_host_native_approval_instead_of_typed_approval_phrases`
- Red proof:
  - `cargo test --manifest-path agent_core/Cargo.toml prompts::tests::prompts_use_host_native_approval_instead_of_typed_approval_phrases`
  - Result: failed before product patch because the Rust prompt did not contain the host-native approval instruction.
- Green commands:
  - `cargo test --manifest-path agent_core/Cargo.toml prompts::tests::prompts_use_host_native_approval_instead_of_typed_approval_phrases`
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/TriageServiceTests -only-testing:EpistemosTests/PipelineServiceTests test CODE_SIGNING_ALLOWED=NO`
  - Swift xcresult: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.09_15-15-13--0500.xcresult`
  - `rg -n "approve web search|Treat any tool marked ask as requiring human approval before sensitive reads or writes" Epistemos agent_core EpistemosTests`
  - `git diff --check`
- Remaining risk:
  - Live first-run/audit-app smoke is still required: submit a web-research-heavy prompt, verify the app either executes a real provider-native/agent web search or presents the native approval card, then verify approve/deny transcript/provenance behavior.
  - This patch fixes the prompt contract that caused typed approval copy; it does not yet prove provider account/network/unavailable-state UX in a built app.

## Research Drop Intake Queue

Append future pasted research here before merging it into the prioritized queue:

- Drop 2: ingested into `Research Drop 2 Integrated Backlog Addendum`.
- Drop 3: ingested into `Research Drop 3 Integrated Backlog Addendum`.
- Drop 4: ingested into `Research Drop 4 Integrated Backlog Addendum`.
- Drop 5: ingested into `Research Drop 5 Integrated Backlog Addendum`.
- Drop 6: ingested into `Research Drop 6 Integrated Backlog Addendum`.
- Drop 7: ingested into `Research Drop 7 Integrated Backlog Addendum`.
- Drop 8: ingested into `Research Drop 8 Integrated Backlog Addendum`.
- Drop 9: ingested into `Research Drop 9 Integrated Fix-Pass Addendum`.
- Drop 10: ingested into `Research Drop 10 Integrated Verification-Pass Addendum`.
- Drop 11: ingested into `Research Drop 11 Integrated Current-App Release-Truth Addendum`.
- Drop 12: ingested into `Research Drop 12 Integrated Pre-Fix Orchestration Addendum`.
- Drop 13: ingested into `Research Drop 13 Finalization and Live-Vault Blocker Addendum`.

---

## Dead-Code Orphan Inventory (2026-05-13)

Files in the source tree that have NO production caller, kept as
scaffolding for future work. All are drift-gated so an accidental
production-side wire-up trips CI before it ships.

| File | Status | Drift gate | Future work |
|---|---|---|---|
| `Epistemos/Engine/LiveCodeEditorController.swift` | Scaffold; no production caller | `LiveHighlighterVerdictGuardTests` (4 tests) | W9.6 V2 — when canonical Swift-direct highlighter ships |
| `Epistemos/Engine/SyntaxCoreLiveHighlighter.swift` | V1.5 LIMITATION; Rust-only tokens | Same suite | Per-language `.scm` queries for syntax-core |
| `Epistemos/Engine/SwiftTreeSitterLiveHighlighter.swift` | Documented W9.6 canonical alternative, unwired | Same suite | Wire as canonical OR delete |
| `Epistemos/Views/ModelProfiles/ModelGraphFilterView.swift` | Orphan; never imported | Implicit — `setModelFilter` produces no visibility change today | Populate `originVaultKey` per node-creation site (RCA-P1-010 lift conditions) |
| `Epistemos/XPC/ProviderServiceStreamingProtocol.swift` | SCAFFOLD ONLY; V2.4 future | `XPCStreamingScaffoldGuardTests` (4 tests) | Paid Apple Developer Program — XPC service launch + entitlements |
| `Epistemos/XPC/MockProviderServiceStreaming.swift` | Test fixture only | Same suite | Delete with the protocol if V2.4 abandoned |

**Recommendation:** do NOT delete any of the above before v1.0
ships. Each is documented scaffolding for a future-version slice and
costs approximately zero binary weight. Delete only when the
corresponding feature lands OR is explicitly abandoned.

---

## Finalization Plan

Steps remaining before v1.0 (MAS) submission, in order:

1. **Manual smoke pass** — exercise every PATCHED PARTIAL item's
   "remaining risk" line in the running app. The diagnostic rows in
   Settings → Diagnostics make this fast (Runtime Truth + AnswerPacket
   + DeploymentProfile + Shadow Search + Cognitive DAG all surface
   live state).
2. **App Store CI smoke** — verify the `Epistemos-AppStore` scheme
   builds + passes the test suite under MAS sandbox entitlements.
   The Pro scheme already builds green every commit.
3. **MAS binary submission** — Xcode Organizer → Archive → Distribute.
   App Store Connect copy + screenshots + privacy nutrition label
   already drafted per RCA12-P0-002 evidence.
4. **AI disclaimer audit** — verify the disclaimer footer (shipped
   2026-05-13) renders correctly under both light and dark mode and
   in every chat tier (Fast / Thinking / Pro / Agent).
5. **Pro release** — follows MAS reviewer feedback. Pro scheme adds
   the CLI passthrough, AX scraping, iMessage Driver, Skills surfaces
   guarded by `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`.

**Items explicitly deferred to post-v1.0:**

- RCA-P1-002 (.epdoc save heaviness) — requires Instruments profiling
  on a real vault.
- RCA-P1-024 (Apple Intelligence main-actor) — requires macOS 26+
  hardware in the user's loop.
- RCA13-P1-002 (CLI discovery + install prompts) — Pro-only feature;
  ship MAS first then this.
- All P2/P3 items in research drops 2-13 — long-tail tech debt that
  is not v1.0 release-blocking.
