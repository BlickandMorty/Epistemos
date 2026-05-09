# Recursive Current-App Audit TODO - Research Drop 1

Date: 2026-05-09

Status: Living backlog. This file ingests the first pasted research set and turns it into a recursive Codex work queue.

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

Status: TODO

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

Status: TODO

Subsystem: `.epdoc` document persistence, autosave, readable blocks, graph projection.

Research signal: The save path reportedly recomputes content hash, complexity, Markdown shadow, plain text, readable block JSONL, graph projection, and indexing on synchronous document write/autosave paths.

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

Status: TODO

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

Status: TODO

Subsystem: main chat commands, Omega MCP, LocalAgent compatibility, Agent Core tools, UI truth.

Research signal: The pasted audits identify at least four different inventories: 13 main chat slash commands, 40 Omega MCP tools, 107 LocalAgent compatibility patterns, and a separate Agent Core registry. The discrepancy is real and must not be flattened.

Files to inspect:
- `ACCSlashCommand`
- Slash command parser and popover/composer files.
- `ToolTierBridge`
- `MCPBridge`
- Omega MCP tool registry.
- `LocalAgentCapabilityRegistry`
- `LocalAgentCommandDispatcher`
- `LocalAgentLoop`
- Rust `agent-core` tool registry and tier/build gates.
- Settings or UI surfaces advertising tools.

Audit steps:
- Generate a table with: advertised name, parsed name, runtime executor, gate, target/build availability, permission class, visible success/failure, tests.
- Normalize aliases such as terminal and web tool names into a single canonical map.
- Compare Fast, Thinking, Pro, Agent, local, cloud, MAS, and Pro build modes.

Acceptance:
- No UI or docs show a tool as available unless it is parsed, executable, gated, and surfaced correctly in that mode.
- Counts are explained as separate inventories, not contradictory totals.

### RCA-P1-005 - Prove Pro + cloud uses the real tool loop when tools are needed

Status: TODO

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

Status: TODO

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

### RCA-P1-009 - Fix graph-created note placeholder duplication and stale manual edges

Status: TODO

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

### RCA-P1-010 - Make graph filters actually affect visibility or hide the UI

Status: TODO

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

### RCA-P1-011 - Move graph scan orchestration and N+1 block fetches off hot UI paths

Status: TODO

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

### RCA-P1-012 - Offload fallback semantic clustering

Status: TODO

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

### RCA-P1-013 - Surface Shadow search backend failures to Halo users

Status: TODO

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

### RCA-P1-014 - Resolve live syntax highlighter drift

Status: TODO

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

### RCA-P1-015 - Move AgentGrepService search and file reads off the main actor

Status: TODO

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
- Results preserve provenance and error reporting.

### RCA-P1-016 - Fix dead `needsCloud` capability banner contract

Status: TODO

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

Status: TODO

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

### RCA-P1-018 - Hide, gate, or complete XPC streaming

Status: TODO

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

### RCA-P1-019 - Wire or suppress GenUI action panels

Status: TODO

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

Status: TODO

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

Status: TODO

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

Status: TODO

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

Status: TODO

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

Status: TODO

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

## P2 Queue

### RCA-P2-001 - Wire or de-scope AnswerPacket / ClaimKind / VRMLabel

Status: TODO

Subsystem: chat output, provenance, preserved architecture.

Research signal: Schemas and tests reportedly exist, but real chat does not emit AnswerPacket today.

Audit steps:
- Search every chat response path for AnswerPacket emission.
- If absent, remove current-product claims or wire the actual path.

Acceptance:
- Product docs/UI do not imply AnswerPacket exists unless real chat emits it.

### RCA-P2-002 - Fix FSRS risk-cache/comment drift

Status: TODO

Subsystem: FSRS, memory decay, NightBrain.

Research signal: `sortedByRiskCache` is reportedly invalidated but not consumed; `topAtRisk()` scans/recomputes/sorts every call despite comments claiming O(K).

Audit steps:
- Inspect `FSRSDecayStore`.
- Benchmark 10k rows.
- Either implement cache usage correctly or delete cache/comments.

Acceptance:
- Comments match actual complexity and tests cover large-row behavior.

### RCA-P2-003 - Split active runtime schemas from roadmap gaps in StructureRegistry

Status: TODO

Subsystem: agent introspection, MCP resources, settings diagnostics.

Research signal: `StructureRegistry` reportedly exposes raw `Gap` entries and prompt descriptors as canonical host knowledge.

Audit steps:
- Dump in-app registry and MCP resource output.
- Verify whether raw gaps appear as active capabilities.
- Split active runtime schemas from roadmap/gap inventory.

Acceptance:
- Agents and settings cannot confuse gaps with implemented features.

### RCA-P2-004 - Make structured query grammar match implementation

Status: TODO

Subsystem: query DSL, graph/search filters, user parser.

Research signal: `StructuredQueryParser` reportedly advertises `|`, grouping, and graph functions but top-level parsing only handles `&`.

Audit steps:
- Feed documented examples using `|`, parentheses, and graph functions.
- Trace user entry points if any.
- Implement grammar or downgrade docs/UI.

Acceptance:
- Surfaced query syntax is actually parsed and tested.

### RCA-P2-005 - Prove editor file-edit tools have an execution and approval loop

Status: TODO

Subsystem: editor skills, file edit schemas, approval, audit log.

Research signal: `edit_file`, `replace_file`, `insert_at_line`, and `delete_lines` schemas/prompts exist, but uploaded evidence did not prove parser, approval surface, executor selection, audit log, or visible result.

Audit steps:
- Trace one file-edit tool from prompt/schema to user approval to file change to transcript/result.
- Verify denials and errors.

Acceptance:
- File-edit tools are either fully executable with approval or hidden from current users/models.

### RCA-P2-006 - Simplify or complete AgentQueryEngine permission events

Status: TODO

Subsystem: agent query runtime, approval prompts, event stream.

Research signal: Event enum reportedly defines `permissionRequest`/`permissionDenied`, but run loop does not emit request and stored denials do not stream back.

Audit steps:
- Force a denied tool call and inspect event stream.
- Either wire request/denial flow or simplify event contract.

Acceptance:
- UI cannot assume permission prompts are integrated unless they actually are.

### RCA-P2-007 - Preserve structured chat history through AgentQueryEngine

Status: TODO

Subsystem: multi-turn agent sessions, tool continuation, replay/provenance.

Research signal: `AgentQueryEngine` reportedly flattens role/tool-call-bearing `QueryMessage` history to plain strings.

Audit steps:
- Compare multi-turn tool sessions through structured and flattened history.
- Inspect concrete backend expectations.

Acceptance:
- Tool continuation and replay preserve roles and tool-call IDs when needed.

### RCA-P2-008 - Classify sidecars, FSRS, speech, query DSL, hooks, paste intelligence, and EventDrain by caller proof

Status: TODO

Subsystem: half-built feature ring.

Research signal: Several sophisticated subsystems appear implemented but not user-reachable in uploaded evidence.

Audit steps:
- For each subsystem, find entry point, runtime path, gate, user surface, test, and final status.
- Hide, gate, or delete any feature with no caller chain.

Acceptance:
- No half-built subsystem is counted as user-facing without reachability proof.

### RCA-P2-009 - Hide mock-only intelligence surfaces

Status: TODO

Subsystem: mask predictor, ANE backend, XPC mocks, future kernels.

Research signal: Placeholder mask predictor always unavailable, ANE is mock-only, XPC streaming mocks exist, and several Helios kernels self-label no production caller.

Audit steps:
- Search UI/docs/settings for each mock-only feature.
- Ensure each is hidden, gated, or labeled experimental/scaffold.

Acceptance:
- Normal users never see mock-only features as working product features.

### RCA-P2-010 - Quarantine orphan candidates and archived runtimes

Status: TODO

Subsystem: repo hygiene, dead code, cognitive load.

Research signal: Many files are orphan candidates or intentionally archived: `AgentRuntime`, `LocalRustRuntime`, `KnowledgeCoreBridge`, `KnowledgeIndexBuilder`, `LiveCodeEditorController`, LSP layer, `IntakeValve`, `KaTeXSnippets`, `KANPilotScaffold`, `LocalGuardrailScaffold`, `KIVIQuantization`, `Mamba2ForwardPass`, and disabled diagnostics.

Audit steps:
- `rg` caller chains for each candidate.
- Classify as live, hidden-working, implemented-not-wired, scaffold-only, or archived.
- Move/rename/quarantine where appropriate.

Acceptance:
- Archived/scaffold code cannot be mistaken for current runtime.

### RCA-P2-011 - Prove Graph Chat, page subgraph, and BTK subscriptions are reachable or hide them

Status: TODO

Subsystem: graph workspace, chat handoff, page mode, BTK polling.

Research signal: Graph Chat may only post a notification, page subgraph comments say no current callers, and BTK polling has no owner in uploaded evidence.

Audit steps:
- Invoke Ask Graph Chat from a node and verify composer opens with context.
- Instrument whether `buildPageSubgraph` ever fires.
- Find owner for BTK subscription state and validate lifecycle shutdown.

Acceptance:
- Each feature is visible-working or hidden/gated as an almost-feature.

### RCA-P2-012 - Finish or de-scope tag/source extraction

Status: TODO

Subsystem: graph semantic extraction, tags, sources, AI scan.

Research signal: Extraction types/comments support tags and sources, but processing reportedly persists only cross-note links.

Audit steps:
- Scan notes with obvious tags/sources.
- Verify whether tag/source graph nodes ever appear.
- Align prompt, processor, graph visibility, and UI claims.

Acceptance:
- Tag/source extraction is either implemented end to end or removed from current claims.

### RCA-P2-013 - Move Spotlight reindex work away from main-actor batch orchestration

Status: TODO

Subsystem: Spotlight, vault load, indexing.

Research signal: `SpotlightIndexer.reindexAll` reportedly dispatches batch orchestration onto `Task { @MainActor in ... }` and sequentially awaits page-body loading.

Audit steps:
- Profile vault-load reindex on medium and large vaults.
- Move body loading and item construction off-main where safe.

Acceptance:
- Spotlight reindexing does not freeze vault-load interaction.

### RCA-P2-014 - Add freshness proof for Shadow vault indexing

Status: TODO

Subsystem: Shadow indexing, Halo recall, file watchers.

Research signal: Bootstrap exists, but follow-up watcher wiring may be deferred. Externally changed notes/chats may not update index without relaunch.

Audit steps:
- Attach vault, let shadow bootstrap finish.
- Modify/add notes externally.
- Verify index updates without relaunch.

Acceptance:
- Shadow recall stays fresh after external changes, or UI reports index is stale/manual refresh required.

### RCA-P2-015 - Fix SidecarCache complexity claim or implementation

Status: TODO

Subsystem: sidecar cache, graph overlay performance.

Research signal: Cache was added to remove per-frame I/O, but `touchLocked` reportedly uses `firstIndex(of:)` under lock despite O(1) comments.

Audit steps:
- Profile hot lookups on graph overlay.
- Replace LRU bookkeeping if lock-held linear work matters.

Acceptance:
- Cache comments and measured complexity match the implementation.

### RCA-P2-016 - Audit SDF label glyph budget clamp

Status: TODO

Subsystem: graph renderer, label atlas, per-frame allocations.

Research signal: SDF label builder has a scratch buffer and budget cap, but inner break condition may compare against the wrong limit.

Audit steps:
- Inspect label instance builder budget logic.
- Add stress test for many labels/long labels.

Acceptance:
- Glyph budget is strictly enforced with no unexpected overrun or frame hitch.

### RCA-P2-017 - Map generated tests and guard scripts to real user flows

Status: TODO

Subsystem: test truth, release confidence.

Research signal: Generated tests and `omega_verify.sh` validate presence/patterns more than runtime behavior.

Audit steps:
- Inventory generated tests versus real user flows.
- Mark tests as runtime proof only when they exercise the real path.

Acceptance:
- Release evidence distinguishes compile/pattern checks from end-to-end behavior.

## P3 Queue

### RCA-P3-001 - Split utility gravity wells

Status: TODO

Subsystem: maintainability.

Research signal: `Extensions.swift` reportedly contains filesystem helpers, decoding heuristics, output sanitizer, UTF-8 cache, and trigram indexing in one utility gravity well.

Acceptance:
- Useful code remains, but unrelated utility clusters are split only when doing so reduces real maintenance cost.

### RCA-P3-002 - Audit Pro bundle weight and build fragility

Status: TODO

Subsystem: build pipeline, bundle contents, release operations.

Research signal: Pro builds include Rust universal binaries, UniFFI, editor bundle, Python/Hermes/MoLoRA/runtime assets, and multiple scripts. Scripts are disciplined but operationally heavy.

Acceptance:
- Bundle contents are intentional, target-gated, measured, and documented.

### RCA-P3-003 - Label diagnostics and scaffolds consistently

Status: TODO

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

Status: TODO

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

### RCA2-P0-002 - Constrain CodeFileService to the vault root

Status: TODO

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

### RCA2-P0-003 - Privacy-audit Vault Organizer scan prompts before treating it as safe

Status: TODO

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

Status: TODO

Subsystem: chat composer voice input, STT, draft editing.

Research signal: The composer reportedly has `ComposerMicButton` using `insertVoiceTranscript` to append without clobbering drafts, while a macOS 26 `VoiceInputButton` assigns `text = partial` and `text = final`.

Files to inspect:
- `ChatInputBar.swift`
- `ComposerVoiceInputService.swift`
- `VoiceInputButton.swift`
- `VoicePreferences.swift`
- cursor-range insertion helpers.

Audit steps:
- Pre-fill composer with a multi-line draft.
- Test both mic buttons with partial and final transcripts on macOS 26.
- Confirm whether both surfaces can be active/discoverable at once.
- Merge both paths into a shared append-at-cursor or replace-selection behavior.

Acceptance:
- Dictation never overwrites an in-progress draft unless the user selected text for replacement.
- The composer exposes one coherent mic surface per platform/mode.

### RCA2-P1-002 - Delete successful voice recording temp files

Status: TODO

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

Status: TODO

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

### RCA2-P1-004 - Remove render-time SwiftData work from chat mention/reference search

Status: TODO

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

### RCA2-P1-005 - Make Vault Organizer scan scope and failure states honest

Status: TODO

Subsystem: Vault Organizer, AI suggestions, UX truth, error handling.

Research signal: The UI says "Scan Vault" and "Analyzing your vault," but the implementation reportedly inspects only the first 20 untagged notes and first 20 loose notes. Generation and JSON decode failures log only; empty suggestions fall through to "well organized."

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

Status: TODO

Subsystem: Vault Organizer concurrency, SwiftData, VaultSyncService, filesystem consistency.

Research signal: Research says scan tasks have session IDs but no post-await guard before appending suggestions. Apply saves SwiftData first, then calls `vaultSync.movePage` or `vaultSync.createDirectory`, with no visible rollback or error propagation.

Files to inspect:
- `VaultOrganizerView.swift`
- `VaultSyncService.swift`
- `SDPage.swift`
- `SDFolder.swift`
- retry/rollback/sync recovery logic.

Audit steps:
- Inject artificial delay into `generateGeneral`, cancel scan, start another scan, and watch for stale suggestions.
- Force sync failure after successful SwiftData save.
- Compare DB state, UI state, and on-disk vault before and after relaunch.

Acceptance:
- Canceled/stale scan results cannot mutate current UI state.
- Apply All is batched or transactionally safe across SwiftData and filesystem sync.

### RCA2-P1-007 - Move Vault Organizer scan/apply work off the UI hot path

Status: TODO

Subsystem: Vault Organizer performance.

Research signal: The scan task reportedly runs on `@MainActor`, filters pages, builds prompts, flattens tag inventories, and applies suggestions through synchronous fetch/save loops.

Files to inspect:
- `VaultOrganizerView.swift`
- SwiftData query owners.
- `VaultSyncService.swift`

Audit steps:
- Profile Scan Vault and Apply All on a large seeded vault.
- Measure main-thread time, SwiftData saves/refetches, filesystem calls, and state-update bursts.

Acceptance:
- Scan and Apply All are responsive, cancellable, and do not perform large prompt assembly or filesystem sync loops on the UI actor.

### RCA2-P1-008 - Move QueryEngine/RetrievalRuntime work off the main actor

Status: TODO

Subsystem: search, query runtime, semantic retrieval, prepared reranking, reactive search.

Research signal: `QueryEngine`, `QueryRuntime`, `RetrievalRuntime`, and prepared-index scoring reportedly run on `@MainActor`, while doing note search, block search, semantic search, graph hints, FFI reranking, and sorting.

Files to inspect:
- `QueryEngine.swift`
- `QueryRuntime.swift`
- `RetrievalRuntime`
- `SearchIndexService.swift`
- `GraphStore.swift`
- `GraphState.swift`
- `RRFFusionFlags`
- `FusionWeights`
- prepared retrieval config/types.

Audit steps:
- Time-profile typing in the real search field.
- Repeat with reactive mode, prepared retrieval, and fusion flags enabled.
- Isolate UI state mutation on `@MainActor`; move retrieval/ranking to background actors where safe.

Acceptance:
- Search typing does not show main-thread spikes in parsing, retrieval, FFI scoring, or reranking.

### RCA2-P1-009 - Fix ReactiveQuery equivalence so ranking/snippet updates emit

Status: TODO

Subsystem: live search, reactive query updates, graph-sensitive retrieval.

Research signal: `QueryResult.isEquivalent` reportedly compares only node-ID sets and edge count, ignoring score, ordering, snippets, and metadata.

Files to inspect:
- `ReactiveQuery.swift`
- `QueryResult`
- `QueryResultNode`
- search result view models.

Audit steps:
- Keep node set constant while changing ranking input, snippets, or graph-event hints.
- Verify whether UI refreshes.

Acceptance:
- Equivalence includes every field that can change visible order, snippet, score, badge, or metadata.

### RCA2-P1-010 - Debounce code-file save cadence and remove sync disk writes from each edit

Status: TODO

Subsystem: code editor, code-file persistence, SwiftData, file I/O.

Research signal: `NoteDetailWorkspaceView` reportedly passes `CodeEditorView.onContentChange` directly into `saveCodeFileContent(...)`, which writes file content synchronously and saves SwiftData. If CodeEditorView emits per keystroke, this is severe.

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

Status: TODO

Subsystem: note workspace, word count, table of contents, outline overlay.

Research signal: Metrics refresh reportedly triggers on initial appear, `pageBodyDidChange`, and a `ProseEditorUserDidType` notification that only fires for short text length. Main body text changes debounce saves but may not refresh metrics/outline live.

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

Status: TODO

Subsystem: code editor, semantic sidebar, LSP hover/definition, breadcrumbs.

Research signal: Cross-file Go to Definition reportedly stops at a "not wired yet" status. Semantic sidebar is hard-gated off with no toggle. Breadcrumb containment reportedly uses start-line-only logic and `prefix(2)`, which cannot model nested symbol ranges.

Files to inspect:
- `CodeEditorView.swift`
- `EditorBreadcrumbBar.swift`
- `OutlineItem`
- outline parser/cache.
- file/tab navigation manager.
- `RustLSPTransport.swift`
- `LSPClient.swift`

Audit steps:
- Test same-file and cross-file definitions.
- Search every current menu/toolbar/preference for a semantic-sidebar reveal path.
- Run nested-symbol breadcrumb tests across sibling boundaries.

Acceptance:
- Visible semantic buttons either work end to end or are hidden/disabled.
- Breadcrumbs are derived from real symbol intervals, not start-line heuristics.

### RCA2-P1-014 - Reconcile `/image` slash command with runtime and build policy

Status: TODO

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

### RCA2-P1-015 - Add App Store scheme test coverage or explicit CI equivalent

Status: TODO

Subsystem: release CI, MAS target, distribution safety.

Research signal: Uploaded scheme files reportedly show the App Store scheme has empty `Testables`, while the main scheme includes `EpistemosTests`.

Files to inspect:
- `Epistemos-AppStore.xcscheme`
- main `Epistemos.xcscheme`
- CI workflow files.
- App Store target tests/smoke scripts.

Audit steps:
- Run current CI matrix and record what App Store target actually tests.
- Add MAS-specific smoke tests or explicit CI script coverage if the scheme is empty.

Acceptance:
- App Store target has test or smoke coverage for sandbox gating, stripped frameworks, first-window recovery, and visible settings honesty.

### RCA2-P1-016 - Fail visibly when local tool bridge has zero tools

Status: TODO

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

Status: TODO

Subsystem: landing page, search overlay, animations.

Research signal: Prior audit reportedly measured active search overlay CPU at 15.8 percent and explicitly said not to call it fixed without longer profiling.

Files to inspect:
- `LandingView.swift`
- search overlay state/views.
- animation/wave choreography files.

Audit steps:
- Instruments Time Profiler and Animation Hitches while opening, typing in, and closing landing search.
- Repeat with reduce motion and occluded window states.

Acceptance:
- Search overlay CPU and animation cost are bounded and measured under realistic use.

### RCA2-P2-001 - Wire file-edit results into a real Apply/Reject diff card or hide file-edit artifacts

Status: TODO

Subsystem: file-edit tools, artifact rendering, safe apply/reject UX.

Research signal: `DiffPreviewView` reportedly claims to render in `MessageBubble` with Apply/Reject, but the uploaded bubble path renders tool previews, markdown, reasoning, and `ArtifactBlockView`; `.fileEdit` artifacts render as plain code.

Files to inspect:
- `DiffPreviewView.swift`
- `MessageBubble.swift`
- `ArtifactBlockView.swift`
- `FileEditOperation.swift`
- tool-result to artifact mapping code.

Audit steps:
- Force a chat response with file-edit content/tool result.
- Verify whether actionable diff controls appear.

Acceptance:
- Live file-edit outputs have safe Apply/Reject controls, or file-edit surfacing is hidden until they do.

### RCA2-P2-002 - Preserve visible assistant output in copy/export/Send to Notes

Status: TODO

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

Status: TODO

Subsystem: chat transcript formatting, assistant message presentation.

Research signal: `ChatTranscriptRow` has heading state and `MessageBubble` can render it, but `heading(forAssistantText:)` always returns nil while first assistant markdown heading may be stripped.

Files to inspect:
- `ChatView.swift`
- transcript row builder.
- `MessageBubble.swift`
- formatter tests.

Audit steps:
- Make the first assistant response start with a unique markdown heading.
- Verify whether it survives onscreen, copy, export, and note creation.

Acceptance:
- The heading lane is implemented end to end, or removed without stripping user-visible structure.

### RCA2-P2-004 - Reclassify or productize worker sessions

Status: TODO

Subsystem: chat history/sidebar, worker sessions, mini chat/open routing.

Research signal: Sidebar comments reportedly say the worker-session marker icon is the only UI reading `isWorkerSession`, while normal chats can be promoted from context menu.

Files to inspect:
- `ChatSidebarView.swift`
- `SDChat.swift`
- worker-session routing files.
- mini-chat/open routing.

Audit steps:
- Promote chat to worker session, restart, search history, open in sidebar and mini chat.
- Record behavior differences beyond the icon.

Acceptance:
- Worker sessions have coherent user-visible behavior or the context-menu promotion is hidden/deleted.

### RCA2-P2-005 - Fix Vault Organizer duplicate/folder-suggestion drift

Status: TODO

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

Status: TODO

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

Status: TODO

Subsystem: prose editor, TextKit 2, markdown styling.

Research signal: `MarkdownContentStorage` reportedly reparses full document when dirty inside `textParagraphWith`, and runs inline markdown parse per paragraph for non-code paragraphs.

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

Status: TODO

Subsystem: backlinks, transclusion overlays, block references.

Research signal: Backlinks popover reportedly fetches all active pages and loads bodies to search for `[[pageTitle]]`. Transclusion refresh does document-wide contains checks and synchronous `page.loadBody()` in edit path.

Files to inspect:
- `NoteBacklinksPanel.swift`
- `EditableTransclusionView`
- transclusion manager.
- `SDPage.loadBody*`
- block-ref index/BTK handlers.

Audit steps:
- Open backlinks in a large vault and measure body loads.
- Edit a transclusion and sample main-thread stalls.

Acceptance:
- Backlinks use an index or cached relation store.
- Transclusion edits are debounced/staged without synchronous full-body reads on the interaction path.

### RCA2-P2-011 - Resolve deterministic outline runtime truth

Status: TODO

Subsystem: note outline, KnowledgeCore runtime bridge, feature flags.

Research signal: `KnowledgeCoreOutlineProjectionState` reportedly subscribes/ingests/drains runtime payloads, but applies fallback headings as displayed items. This makes the deterministic runtime surface look like it is still showing markdown fallback output.

Files to inspect:
- `NoteTableOfContents.swift`
- `KnowledgeCoreBridge`
- `KnowledgeCoreRuntimeBinding`
- adapter result types.
- feature flag plumbing.

Audit steps:
- Enable deterministic outline flag.
- Use document where runtime output should differ from markdown headings.
- Compare actual overlay items.

Acceptance:
- Runtime flag surfaces real runtime-derived items, or the deterministic outline claim is hidden/downgraded.

### RCA2-P2-012 - Audit QuarantineArchive and ambient retrieval privacy/durability

Status: TODO

Subsystem: raw thoughts, ambient retrieval, quarantine archive, chat header chip.

Research signal: Ambient retrieval promises default-off raw-thought access and `raw:`/`curated:` labels, but current storage may be in-memory plus JSONL append fallback. Capture returns before disk persistence completes, and directory creation failure may no-op.

Files to inspect:
- `QuarantineArchive`
- `AmbientRetrievalToggle`
- chat header chip.
- retrieval tool builders.
- shutdown/persistence coordinator.

Audit steps:
- Verify raw content is inaccessible when toggle is off and labeled `raw:` when on.
- Simulate disk-full and immediate app quit after capture.

Acceptance:
- Privacy and durability contracts are proven end to end or the feature remains hidden.

### RCA2-P2-013 - Reconcile provenance authority and fail-closed diagnostics

Status: TODO

Subsystem: provenance console, EventStore, cognitive DAG, legacy ledger.

Research signal: Console claims DAG is live authority, DAG client says authority flip is future, legacy ledger says no longer visible authority, and failures may return empty placeholders.

Files to inspect:
- provenance console UI/view model.
- `EventStore`
- Rust DAG clients.
- legacy ledger bridge.
- current authority/migration docs.

Audit steps:
- Run console with DAG FFI present and absent.
- Verify user/developer messaging distinguishes unavailable backend from no data.

Acceptance:
- One source of truth is named consistently.
- Legacy counts are demoted clearly and backend failure is visible.

### RCA2-P2-014 - Complete or gate SessionTelemetry classifier migration

Status: TODO

Subsystem: session continuation, compaction, conversation state.

Research signal: SessionTelemetry schema says it replaces the naive summarizer, while classifier service says legacy prose call sites remain until migration.

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

Status: TODO

Subsystem: note storage migration, event drain, provider XPC streaming.

Research signal: Rope client says future PR4 consumer; Rust event ring is compile-flag gated; provider streaming protocol/mock exist but production XPC launch/entitlements are future work.

Files to inspect:
- `RopeFFIClient`
- note storage migration hooks.
- `RustEventRingClient`
- `EventDrain`
- project config for `EPISTEMOS_LINK_SUBSTRATE_RT`
- provider XPC client/service targets.

Audit steps:
- Search active build references.
- Prove each is live, feature-gated, or scaffold-only.

Acceptance:
- Scaffold-only infrastructure is excluded from current-app claims and isolated from normal product UI.

### RCA2-P2-016 - Prove `.epdoc` source-guard claims with runtime tests

Status: TODO

Subsystem: `.epdoc` editor/runtime proof, test truth.

Research signal: Epdoc source-guard tests string-match source files for rich toolbar/bridge/editor claims. They are useful but not runtime evidence.

Files to inspect:
- `EpdocVisibilitySourceGuardTests`
- `.epdoc` UI/integration tests.
- `EpdocDocument`
- editor bridge and toolbar files.

Audit steps:
- Add runtime/UI tests that create `.epdoc`, open it, type, save, reopen, use toolbar/menu, insert image, and verify graph/search projection.

Acceptance:
- Source guards remain drift checks, but runtime evidence carries product-readiness claims.

### RCA2-P2-017 - Add retention and privacy policy for brain snapshots/model input capture

Status: TODO

Subsystem: ChatState, brain/context panel, captured model inputs, disk persistence.

Research signal: ChatState persists brain snapshots and captured model inputs to disk. This is useful transparency, but long prompts and tool definitions may become large and privacy-sensitive.

Files to inspect:
- `ChatState.swift`
- brain/context panel UI.
- persistence paths and cleanup policies.
- privacy settings/diagnostics export.

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

Status: TODO

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

Status: TODO

Subsystem: `.epdoc` source-of-truth, ProseMirror JSON, Markdown shadow, external edits.

Research signal: `.epdoc` uses canonical `content.json`/`content.pm.json`, shadow Markdown, readable blocks, search JSONL, and assets. External shadow Markdown edits must not silently overwrite canonical document JSON. Prior research classifies this as source-of-truth drift/data-loss risk until tested.

Files to inspect:
- `EpdocDocument.swift`
- `EpdocPackage.swift`
- `ProseMirrorMarkdownProjector`
- `ReadableBlocksProjector`
- `SearchIndexService`
- `.epdoc` import/reopen/mismatch handling.

Audit steps:
- Create `.epdoc` with text, headings, image, table/chart if supported.
- Save and close.
- Edit `shadow.md` externally in the package.
- Reopen and verify canonical JSON wins or a conflict prompt appears.
- Verify graph/search projection do not overwrite canonical data with stale shadow output.

Acceptance:
- External shadow edits never silently replace canonical ProseMirror JSON.
- Mismatch/conflict behavior is explicit, logged, and user-visible when needed.

### RCA3-P1-001 - Treat `.epdoc` package-local assets as the canonical image path

Status: TODO

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

Status: TODO

Subsystem: Contextual Shadows V0, Halo V1, InstantRecallService, ShadowSearchService, UI naming.

Research signal: Earlier evidence says production V0 mounted through `ContextualShadowsState -> ContextualShadowsButton -> ContextualShadowsPanel` and did not call `ShadowSearchService`/`HaloController`; later evidence says V0 is env-gated, prefers durable `ShadowSearchServicing` when available, and falls back to `InstantRecallService`. V1 `HaloController`/`HaloButton`/`ShadowPanel` is separate and not default-mounted.

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

Status: TODO

Subsystem: audit methodology, docs/product truth, implementation matrix.

Research signal: WRV protocol distinguishes implemented, wired, reachable, visible, verified, and shipped. Drop 3 says this protocol is essential because many Epistemos features are implemented/wired/visible-but-not-verified rather than shipped.

Files to inspect:
- `docs/audits/CURRENT_APP_ARCHITECTURE_RESEARCH_PACKET_2026_05_08.md`
- `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md`
- WRV protocol docs if present.
- Product docs/settings labels with "shipped", "ready", "live", "production".

Audit steps:
- Build a WRV status table for `.epdoc`, graph, search, Halo/Contextual Shadows, GenUI, FSRS, Raw Thoughts, PromptTree, LSP, Provider XPC, ANE, local model downloads, command center, MCP/Omega, and MAS/Pro gates.
- Replace "shipped" language unless visible + verified + release-gated.

Acceptance:
- No subsystem is called shipped/release-ready unless the WRV table proves it.

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

Status: TODO

Subsystem: chat streaming, NoteChatState, PipelineService, SwiftUI invalidation.

Research signal: Current docs say chat is visible/wired but needs proof of no per-token DB save or broad SwiftUI `@Query` cascade, and proof of visible recovery for cancellation/offline/provider errors.

Files to inspect:
- `ChatCoordinator.swift`
- `NoteChatState.swift`
- `PipelineService.swift`
- chat transcript views.
- SwiftData save points.

Audit steps:
- Send long streaming prompt and sample main thread.
- Signpost token append, model save, message mutation, transcript body invalidation.
- Stop mid-stream, disconnect network mid-stream, and force provider errors.

Acceptance:
- Tokens do not trigger DB saves or broad app invalidation per chunk.
- Stop/offline/provider failures have visible recovery states.

### RCA3-P1-007 - Defer prepared model registry synchronous bootstrap load

Status: TODO

Subsystem: AppBootstrap, prepared model registry, startup/first interaction.

Research signal: Follow-up research says a likely foreground/launch stall is synchronous `preparedModelRegistry.load()` in `AppBootstrap.swift`, and suggests deferring it to async refresh with safe empty/default snapshot.

Files to inspect:
- `AppBootstrap.swift`
- prepared model registry files.
- local model settings/UI.

Audit steps:
- Confirm whether registry load is synchronous in launch path.
- Measure launch with large registry/model cache.
- Move to async refresh if still blocking first interaction.

Acceptance:
- Prepared model registry cannot block first window or first click.

### RCA3-P1-008 - Add local model download/storage trust checks

Status: TODO

Subsystem: local model catalog/download, Hugging Face snapshots, disk storage, settings.

Research signal: `ModelDownloadManager` downloads Hugging Face snapshots, verifies config/weights, stages and atomically moves directories. Docs require clear installed/available/storage disclosure.

Files to inspect:
- `ModelDownloadManager`
- local model settings/views.
- Hugging Face cache/model storage files.
- cleanup/remove path.

Audit steps:
- Download a model, cancel midway, resume, delete.
- Verify staging cleanup, active directory integrity, installed size, revision, local/cloud route labels, and remove button.
- Confirm no huge model assets are bundled into MAS unless explicitly declared.

Acceptance:
- Users understand GB footprint, local/cloud route, installed revision, and removal path.
- Partial/canceled downloads do not corrupt active model state.

### RCA3-P1-009 - Add prompt persistence privacy controls for PromptTree/PTF

Status: TODO

Subsystem: PromptTree, prompt rendering/cache/persistence, vault `.epistemos/prompts`, privacy.

Research signal: `PromptTreePersister` reportedly writes prompt subtrees to `<vault>/.epistemos/prompts/<sessionID>/<turnIndex>/` with manifest, identity, tools, memory, task, constraints, and output schema. This is good for auditability but sensitive.

Files to inspect:
- `PromptTree`
- `PromptRenderer`
- `PromptCache`
- `PromptTreePersister`
- chat agent path callers.
- privacy/settings UI.

Audit steps:
- Run chat/agent turn and inspect `.epistemos/prompts`.
- Verify no API keys, OAuth tokens, hidden system secrets, or unintended raw user data are persisted.
- Add purge/export controls and retention policy if missing.

Acceptance:
- Prompt persistence is disclosed and controllable.
- Sensitive fields are redacted by policy and tests.

### RCA3-P1-010 - Audit MeaningAnchorService main-actor model/transcript work

Status: TODO

Subsystem: chat exits, meaning anchors, SwiftData transcript fetch, local analysis/model calls.

Research signal: `MeaningAnchorService` is reportedly `@MainActor`, fetches chats from `modelContainer.mainContext`, builds transcripts, and claims to generate anchors from chat exits.

Files to inspect:
- `MeaningAnchorService`
- model/transcript generation callers.
- local analysis/model invocation.

Audit steps:
- Trace whether model generation happens on `@MainActor`.
- Profile chat-exit anchor creation on long chats.
- Move transcript build/model work off-main with local context if needed.

Acceptance:
- Anchor generation cannot stall UI on chat exit.

### RCA3-P1-011 - Prove Raw Thoughts and Run Artifacts are browsable/recoverable or downgrade claims

Status: TODO

Subsystem: Raw Thoughts, Run Artifacts, timeline, JSONL recovery, event stores.

Research signal: Docs list tests/stores, but persistent browsable timeline and JSONL recovery need proof. Drop 3 classifies Raw Thoughts / Run Artifacts as partial/unknown.

Files to inspect:
- `RawThoughtsState`
- Raw Thoughts views.
- Run artifact stores.
- JSONL recovery code.
- chat/tool trace links.

Audit steps:
- Create run, append event, final output, tool trace, and link.
- Quit/relaunch.
- Verify timeline browsing, recovery, and missing/corrupt JSONL behavior.

Acceptance:
- Raw Thoughts/Run Artifacts are visible-working with recovery proof, or hidden from release claims.

### RCA3-P1-012 - Build command/tool inventory truth table from packets 1-10

Status: TODO

Subsystem: main chat slash, Agent Command Center, MCP/Omega, LocalAgent, Agent Core, CLI passthrough, cloud tool loops.

Research signal: Drop 3 says packets 21-40 cannot reconcile the command/tool universe. Packets 1-10 and specific chat/tool files are required.

Files to inspect first:
- `Epistemos/Engine/CommandInputParser.swift`
- `Epistemos/Engine/CommandCenterRequestCompiler.swift`
- `Epistemos/Views/Chat/*`
- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/Omega/MCPBridge.swift`
- `Epistemos/Omega/OmegaPermissions.swift`
- `LocalAgentLoop.swift`
- `agent_core/src/lib.rs`
- `agent_core/src/tools/registry.rs`
- `agent_core/src/resources/tool_authz.rs`
- `agent_core/src/tools/file_ops.rs`
- `omega-mcp/src/lib.rs`

Audit steps:
- Enumerate visible slash commands in main chat.
- Enumerate `.epdoc` slash commands.
- Enumerate Agent Core tools, Omega/MCP tools, LocalAgent commands, Pro-only CLI passthrough, and cloud tool loops.
- For every row: advertised, parsed, executed, gate, approval, log/event, visible result, MAS/Pro status.

Acceptance:
- Tool-count claims are replaced by a truth table with explicit inventories.

### RCA3-P2-001 - FSRS cache/performance proof

Status: TODO

Subsystem: FSRS decay, GRDB persistence, review UI.

Research signal: GRDB persistence landed and tests exist, but `sortedByRiskCache` optimization is not proven consumed. This overlaps RCA-P2-002 but now has stronger packet context.

Audit steps:
- Benchmark `topAtRisk()` on 10k and 100k rows.
- Verify sorted risk cache use or delete cache/comment.
- Find any UI surfacing review/FSRS state.

Acceptance:
- FSRS status is implemented with measured complexity, or optimization claims are removed.

### RCA3-P2-002 - Guard GenUI `.actionPanel` producers until host callbacks exist

Status: TODO

Subsystem: GenUI dispatcher, action panels, cloud/model response UI.

Research signal: `GenUIDispatcher` maps schemas to renderers, but `ActionPanelGenUIView` button bodies are no-op comments.

Audit steps:
- Find every `.actionPanel` producer.
- Force payload through current surfaces.
- Wire host callbacks or suppress action panel schema.

Acceptance:
- No user can click an inert action button.

### RCA3-P2-003 - Treat MLX image generation as scaffold unless a provider route is explicit

Status: TODO

Subsystem: local image generation, MLX pipelines, `/image` command.

Research signal: MLX image generation code attempts pipeline resolution but defaults to `fluxPipelineUnavailable`; no `flux.swift`, MLXDiffusers package, or configured Flux model is proven.

Files to inspect:
- MLX image generation service.
- `/image` slash command routing.
- provider fallback routes such as fal if present.

Acceptance:
- Local MLX image generation is hidden/unavailable by default unless real model pipeline is installed.
- `/image` routes to an actually available provider or explains unavailability.

### RCA3-P2-004 - Lock Hermes status to one current truth

Status: TODO

Subsystem: Hermes, external CLI/subprocess orchestration, LocalAgent/Omega docs.

Research signal: Canon says some Hermes materials are archive-only/removed from forward work, while other chunks include Hermes subprocess-manager fixes and tests. This creates architecture drift.

Files to inspect:
- Hermes current docs.
- build scripts bundling Hermes/runtime assets.
- LocalAgent/Omega caller paths.
- MAS/Pro gates.

Audit steps:
- Create `HERMES_CURRENT_STATUS.md` or equivalent ledger: runtime present, packaged, build target, user visible, Pro-only, removed, archived.

Acceptance:
- Hermes is not referenced as current runtime unless packaged and user-reachable in the right build.

### RCA3-P2-005 - Keep vendored local LLM corpora out of product feature proof

Status: TODO

Subsystem: LocalPackages, llama.cpp, MLX, vendored dependencies, build/bundle size.

Research signal: Packets 19-21 contain large vendored llama.cpp and MLX source forests. These are dependencies/runtime support, not evidence of user-facing features.

Audit steps:
- Verify build includes only needed library/runtime pieces, not unused tools/server/webui/test corpora.
- Separate dependency presence from product route in docs.

Acceptance:
- Vendored corpora do not inflate current-app feature claims or MAS bundle unexpectedly.

### RCA3-P3-001 - Packet-aware audit coverage plan

Status: TODO

Subsystem: research workflow, packet prioritization.

Research signal: Drop 3 says next high-value audit is packets 1-10, not another giant prompt. Packets 1-8 contain live Swift app/tests, packet 9 graph/widgets/XPC, packet 10 agent_core/bridge.

Packet priority:
- `01_CODE_PACKET.md`: root + primary `Epistemos` app files.
- `02_CODE_PACKET.md` through `06_CODE_PACKET.md`: remaining Swift app files.
- `07_CODE_PACKET.md` and `08_CODE_PACKET.md`: Swift tests.
- `09_CODE_PACKET.md`: graph-engine, widgets, XPC services.
- `10_CODE_PACKET.md`: `agent_core`, graph-engine bridge.
- `19_CODE_PACKET.md` onward: vendored local model/dependency/research-heavy material; use for dependency/runtime proof, not product reachability.

Acceptance:
- Future researchers work packets 1-10 first for caller-chain proof, then move outward to runtime crates, docs, vendored dependencies, and research corpora.

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

Status: TODO

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

Status: TODO

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

Status: TODO

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

Status: TODO

Subsystem: note editor, TextKit 2, markdown parsing, styling.

Research signal: Drop 4 reports that `ProseTextView2.didChangeText()` calls `reparseAndInvalidate()` immediately, and `MarkdownContentStorage.reparse(text:)` rebuilds line starts, calls `markdown_parse_structure`, and clears token cache. This is a visible-working editor path with a severe stutter risk on long notes, tables, code-heavy notes, and paste storms.

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

Status: TODO

Subsystem: code file notes, note detail workspace, code editor persistence, sidecars.

Research signal: Drop 4 reports that `NoteDetailWorkspaceView` passes `codeFileContent(page:filePath:)` into `CodeEditorView`; that helper falls back to `String(contentsOfFile:)`, and `saveCodeFileContent` writes with `content.write(toFile:)`.

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

Status: TODO

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

Status: TODO

Subsystem: Halo, Contextual Shadows, Shadow backend, vault indexing, model downloads.

Research signal: Drop 4 reports that `initializeShadowBackendIfReady` opens the Rust shadow backend, may trigger Model2Vec download, walks the vault, reads `.md`/`.json`, and logs/swallows errors. It is off-main, but still can create invisible CPU/disk/network churn or empty recall panels.

Audit steps:

- Launch with a vault containing 1k markdown files.
- Watch CPU, disk, and network.
- Force backend open failure.
- Force model download failure.
- Force stale vault root.
- Observe Contextual Shadows panel and diagnostics.

Acceptance:

- User sees indexing status.
- User can pause/cancel indexing.
- Model downloads require visible consent or clear first-run disclosure.
- Recall panel distinguishes "no hits" from "backend failed" and "indexing still running."

### RCA4-P1-006 - Collapse duplicate chat dictation paths into one owned voice surface

Status: TODO

Subsystem: chat composer, `ComposerMicButton`, `VoiceInputButton`, speech analyzer, temp audio cleanup.

Research signal: Drop 4 confirms the composer path can include both `ComposerMicButton` and macOS 26 `VoiceInputButton`. They use different backends/lifecycles and can write partial/final transcripts differently.

Audit steps:

- Run on macOS 26.
- Confirm whether two mic buttons are visible.
- Start one, then the other.
- Close composer/window mid-recording.
- Inspect audio engine state and temp files.
- Confirm draft text is not clobbered by partial/final transcript callbacks.

Acceptance:

- Only one mic affordance is visible per build/OS/state.
- Transcript insertion semantics are shared.
- Successful and canceled recordings clean up temp files.

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

Status: TODO

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

Status: TODO

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

### RCA4-P1-011 - Downgrade `AnswerPacket` / VRM claims until chat emits real packets

Status: TODO

Subsystem: `AnswerPacket`, Verified Research Mode, VRM labels, chat streaming delegate.

Research signal: Drop 4 reports the Swift `AnswerPacket` file explicitly says chat path is not yet wired, and the Rust mirror says `state: wired` follows only after the Swift `StreamingDelegate` change lands. That makes runtime AnswerPacket emission implemented-not-wired.

Audit steps:

- Search for `AnswerPacket` emission in chat streaming.
- Run a real chat turn.
- Inspect persisted chat messages, transcript artifacts, run logs, and UI rows for an AnswerPacket id/VRM label.

Acceptance:

- If no runtime emission exists, product claims say "schema ready" or hide VRM/AnswerPacket UI.

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

Status: TODO

Subsystem: Omega panel, confirmation sheet, execution progress view, provider XPC, agent/provider services.

Research signal: Drop 4 says `OmegaPanel` is marked retired; companion views are empty; retired orchestrator tests fail closed; provider XPC streaming protocol and mock exist, but production XPC launch/entitlement provisioning are future work; current service code is only parser/classifier scale.

Audit steps:

- Find every visible "Omega" row or panel entry.
- Find every XPC settings/diagnostics row.
- Confirm retired/scaffold surfaces are hidden or developer-labeled.

Acceptance:

- Users do not see retired Omega execution or production XPC streaming claims.

### RCA4-P2-002 - Treat App Store computer use as denied-by-design and audit UI copy

Status: TODO

Subsystem: `ComputerUseBridge`, App Store stubs, settings, tool catalogs, provider/tool copy.

Research signal: Drop 4 says Pro builds have `ComputerUseBridge` behind `#if !EPISTEMOS_APP_STORE`, while App Store builds return automation-denied stubs. This is correct if UI copy is honest.

Verification:

- Build App Store target.
- Open settings and command/tool surfaces.
- Confirm no App Store row promises working AX automation, screen capture, browser control, or shell/terminal execution.

Acceptance:

- App Store users see unavailable/unsupported language, not failing execution paths.

### RCA4-P2-003 - Preserve local model stack as current-wired, but keep advanced runtime claims exact

Status: TODO

Subsystem: local model manager, MLX, GGUF, local backend, KIVI/KAN/Mamba diagnostics, guardrail scaffolds.

Research signal: Drop 4 says local model stack should not be classified as dead: bootstrap constructs local model manager, local MLX, local GGUF, and local backend client. But KIVI/KAN/Mamba/LocalGuardrail files are scaffold or diagnostics unless caller chains prove otherwise.

Acceptance:

- Local model selection/download/generation stays current.
- KIVI/KAN/Mamba/private ANE/activation steering/guardrail scaffold claims stay hidden or developer-only unless runtime mounted.

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

Status: TODO

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

Status: TODO

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

Status: TODO

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

Status: TODO

Subsystem: live code editor controller, code editor UI, LSP/editing runtime.

Research signal: Drop 5 says `LiveCodeEditorController` has substantial tests but no convincing non-test caller chain in inspected current app surfaces; visible code paths use `CodeEditorView`.

Audit steps:

- Search all production call sites.
- Confirm whether any visible UI instantiates `LiveCodeEditorController`.
- If not, quarantine, delete, or clearly mark as experimental.

Acceptance:

- No product claim counts `LiveCodeEditorController` unless a visible route uses it.

### RCA5-P2-002 - Keep ArenaBridge, ANEBackend, Helios kernels, and XPC provider streaming out of current-product claims

Status: TODO

Subsystem: ArenaBridge, ANEBackend, Helios kernels, XPC services, provider streaming protocol.

Research signal: Drop 5 classifies several subsystems as scaffold-only or implemented-not-wired: `ArenaBridge` has payload clamps, 5 ms polling, and `readSignalEpoch() -> 0`; ANEBackend is protocol/mock/deferred; Helios kernels say reference/no production caller/tier-gated; XPC provider streaming protocol and mocks exist but production launch/entitlements are future.

Acceptance:

- These systems remain hidden/developer-labeled unless real product caller chains exist.

### RCA5-P2-003 - Audit `AgentAuthorityStore` default persistence and enforcement

Status: TODO

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

Status: TODO

Subsystem: HELIOS settings, Helios V5 kernels, private/experimental model runtimes.

Research signal: Drop 6 reports `HELIOSv5SettingsView` exists in Settings packets, while kernels and Rust modules say reference, candidate, no production caller, or tier-gated. Product reachability and defaults must be reviewed.

Audit steps:

- Open Settings in Core/App Store and Pro builds.
- Verify HELIOS/experimental settings are default-off.
- Confirm user copy labels them experimental/research where visible.
- Verify no experimental kernel is activated in ordinary chat/notes/graph routes.

Acceptance:

- HELIOS surfaces do not inflate current-product claims.
- Experimental kernels stay gated and non-default.

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

Status: TODO

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

Status: TODO

Subsystem: `.epdoc` editor chrome, block menus, context menus, Ask Agent, Cite as Source, RawThought capture.

Research signal: Drop 7 reports `.epdoc` block menus expose agent/source actions through closures that default to no-ops. This creates a visible-broken risk if production hosts do not provide callbacks or disable actions.

Audit steps:

- Right-click / open every block, gutter, bubble, and context menu action.
- Check each action has a real host callback in production.
- Verify disabled styling for unavailable actions.

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

Status: TODO

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

Status: TODO

Subsystem: Hermes Expert Mode, LocalAgent compatibility, command dispatcher, GenUI deferred commands.

Research signal: Drop 7 reports Hermes Expert Mode UI shell is around 80% while runtime is around 5%, with many commands echoing behind `GENUI-DEFER` markers. This is visible-broken if exposed as a working expert surface.

Verification:

- Run every visible Hermes command.
- Record side effect, unavailable message, deferred echo, or no-op.
- Confirm normal UI hides commands without real execution.

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

Status: TODO

Subsystem: SwiftData model container initialization, launch recovery, database error UI, data-loss prevention.

Research signal: Drop 8 reports a critical "persistence illusion" risk: when persistent store initialization fails due to schema mismatch, corruption, disk exhaustion, or migration error, the app may catch the error and reinitialize with `isStoredInMemoryOnly: true`. If editing/capture/chat continues, users believe data is saved while it is only in RAM.

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

Status: TODO

Subsystem: MCP stdio transport, Omega/1mcp, XcodeBuildMCP, CLI passthrough, subprocess helpers, environment handling.

Research signal: Drop 8 generalizes the existing credential-env leak: stdio MCP servers and helper processes can inherit the full parent environment, including provider keys, Stripe tokens, or local developer secrets. Keychain storage is not enough if helper launches inherit the process environment.

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

Status: TODO

Subsystem: release/audit workflow, dependency graph, package locks, build scripts, generated packets.

Research signal: Drop 8 frames an "audit-floor commit" as the canonical baseline for measuring Research Drops. It reports partial dependency integrity, possible `Package.resolved` / model-version mismatches, and only partial reproducibility metrics. This should become a concrete baseline gate, not a narrative concept.

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

Status: TODO

Subsystem: Omega MCP, stdio MCP servers, omega doctor, embedding model cache, first launch bootstrap.

Research signal: Drop 8 reports path verification failures around `~/.omega`, `omega_store`, `omega_query`, ONNX embedding model location, and Claude Code stdio server detection. The reported failure mode is a silent server exit when an expected ONNX embedding model/cache path is missing.

Audit steps:

- Inspect first-launch bootstrap for Omega/MCP paths.
- Run "omega doctor" or equivalent diagnostics from a clean user account.
- Remove `~/.omega`.
- Remove embedding model cache.
- Attempt MCP tool discovery and query.
- Check whether the user sees missing asset/path status or only a silent unavailable tool.

Acceptance:

- Required directories are created deterministically or prompted.
- Missing embedding assets are detected before tool use.
- User sees "download required" / "server unavailable" with remediation, not silent tool disappearance.
- App does not require hidden manual shell setup for advertised MCP/Omega features.

### RCA8-P1-003 - Verify ONNX / embedding model asset integrity before enabling memory/search tools

Status: TODO

Subsystem: Omega memory, TESSERA/embedding models, vector search, cross-model memory claims.

Research signal: Drop 8 reports missing ONNX embedding weights and model-version mismatches as a root cause for cross-model memory/Omega failures. It also says advertised cognitive memory features are much simpler at runtime than docs imply.

Audit steps:

- Locate all embedding model asset references.
- Verify checksum/version compatibility at startup or feature activation.
- Remove/corrupt ONNX model and observe UI.
- Confirm vector search and memory tools fail closed with clear remediation.

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

Status: TODO

Subsystem: Apple Intelligence, FoundationModels, model asset lifecycle, LanguageModelSession.

Research signal: Drop 8 reports Foundation Models "Model Catalog" / UnifiedAssetFramework Code 5000 errors when `LanguageModelSession` requests responses before assets are loaded or consistency tokens are resolved. The audit says the app may block while the system resolves asset state.

Audit steps:

- Force FoundationModels asset unavailable / not downloaded / inconsistent state if possible.
- Trigger Apple Intelligence route.
- Capture logs and UI responsiveness.
- Verify retry/backoff is backgrounded and user-visible.

Acceptance:

- Asset-not-ready fails gracefully or retries without blocking main UI.
- Model availability state is visible before route selection.
- Provenance records degraded/fallback route.

### RCA8-P1-006 - Prove AppIntents and external automation surfaces are current-safe, not just present

Status: TODO

Subsystem: AppIntents, Shortcuts/Siri, Quick Capture intents, MCP/XcodeBuildMCP/RenderPreview-like tools.

Research signal: Drop 8 mentions AppIntents and XcodeBuildMCP-style tools as visible-working in research docs but warns that presence/performance is not enough. RenderPreview/headless SwiftUI rendering may exist yet be too slow for complex view hierarchies through bridges.

Audit steps:

- Enumerate AppIntents exposed by the app.
- Run each intent from Shortcuts/Siri/CLI where applicable.
- Verify persistence, permission prompts, and error surfaces.
- If RenderPreview/headless rendering tools are included, profile complex view rendering latency.

Acceptance:

- AppIntent surfaces are either runtime-proven or hidden.
- External automation/rendering tools are not included in consumer/Core truth unless performant and gated.

### RCA8-P1-007 - Separate Core Data bridge / legacy persistence code from SwiftData runtime or quarantine it

Status: TODO

Subsystem: Core Data legacy code, SwiftData, background fetch, migration, hidden-dead persistence paths.

Research signal: Drop 8 reports possible hidden-dead Core Data `NSManagedObject` subclasses and manual context management logic compiled after migration to SwiftData. If background fetches still trigger legacy bridges, they can synchronously block the main thread or corrupt persistence assumptions.

Audit steps:

- Grep for `NSManagedObject`, `NSManagedObjectContext`, `NSPersistentContainer`, and Core Data bridge code.
- Check target membership.
- Trace any background fetch/import paths.
- Confirm no production path bridges Core Data and SwiftData unless explicitly migrated/tested.

Acceptance:

- Legacy Core Data is removed, archived outside product targets, or strictly isolated for migration-only use.
- No hidden-dead persistence code runs in normal app sessions.

### RCA8-P2-001 - Keep Helios Spec Kit, FSRS semantic forgetting, and cognitive memory claims outside product truth until wired

Status: TODO

Subsystem: Helios research, Spec Kit, FSRS, semantic forgetting, causal graph, prediction-error gating, cross-model memory.

Research signal: Drop 8 says Helios docs describe causal graph traversal, Degree scoring, prediction-error gating, semantic forgetting, and FSRS/encoding variability, but runtime may be simpler last-write-wins memory or standalone math islands not wired into primary agent memory.

Audit steps:

- Find current product imports/callers for FSRS, semantic forgetting, causal graph, and prediction-error gates.
- Compare docs/Settings/UI copy to actual runtime.
- Search for CREATE/REINFORCE/UPDATE/SUPERSEDE-style memory transitions in production code.

Acceptance:

- Research capabilities remain in research docs or developer panels unless live caller chains exist.
- Current product copy describes actual memory behavior, not Helios aspirations.

### RCA8-P2-002 - Build a "Truth in Wiring" subsystem classification table in the backlog itself

Status: TODO

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

Acceptance:

- Every major subsystem has a current classification row.
- Future research cannot silently inflate a subsystem from scaffold to shipped without proof.

### RCA8-P2-003 - Track dependency/model asset version mismatches as release blockers when they break runtime features

Status: TODO

Subsystem: package management, local model assets, ONNX/MLX/FoundationModels assets, build reproducibility.

Research signal: Drop 8 mentions dependency-integrity gaps such as `Package.resolved` and ONNX model-version mismatches. The exact claim needs repo verification, but the category is release-critical.

Audit steps:

- Hash and record `Package.resolved`.
- Hash expected model asset manifests.
- Check installed/cached asset versions.
- Run a clean machine bootstrap.

Acceptance:

- Dependency/model asset mismatch is detected before runtime feature activation.
- Missing assets do not cause silent server exit or empty-result UI.

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

Status: CONFIRMED-REQUIRED

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

Status: PARTIALLY-FIXED / NEEDS-RUNTIME-PROOF

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

Status: PARTIALLY-CONFIRMED

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

### RCA9-P2-001 - Downgrade `AnswerPacket` / VRM to implemented-not-wired until chat emits it

Status: CONFIRMED IMPLEMENTED-NOT-WIRED

Canonical owner: `RCA4-P1-011`

Link:

- `RCA-P2-001`

Subsystem: `AnswerPacket`, `VRMLabelView`, Verified Research Mode, chat row rendering, streaming delegate.

Research signal: Drop 9 confirms the source-level truth: `AnswerPacket` exists, but wired state only arrives when Swift emits packets per chat reply. `VRMLabelView` renders labels for emitted packets; it does not prove normal chat rows emit or display those packets.

Required grep:

```bash
rg "AnswerPacket|VRMLabelView|MessageBubble|completeProcessing|StreamingDelegate" Epistemos agent_core
```

Acceptance:

- Product copy says schema-ready or hides VRM if no emitted packet exists.
- A real chat turn creates/persists an `AnswerPacket`.
- Chat row / message bubble displays the packet label or provenance surface.

### RCA9-P2-002 - Mark MLX image generation as scaffold-only unless a real route exists

Status: CONFIRMED SCAFFOLD-ONLY

Canonical owner: `RCA3-P2-003`

Subsystem: `/image`, MLX image generation, provider image route, command truth.

Research signal: Drop 9 confirms `MLXImageGenerationService` explicitly says the Flux/MLXDiffusers pipeline is absent and the default resolver throws `fluxPipelineUnavailable`. That is fine as a future path, but it must not be exposed as a working local image feature.

Acceptance:

- Local MLX image generation is hidden or visibly unavailable unless the actual pipeline/package/model is installed.
- `/image` routes to a real configured provider or returns a clear unavailable/setup message.
- Command/tool truth report marks local MLX image generation as scaffold-only until proven.

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

Status: TODO

Subsystem: PromptTree, PTF persister, vault `.epistemos/prompts`, prompt caching/export, privacy.

Research signal: Drop 9 notes PromptTree/PTF is implemented infrastructure and persists prompt subtrees under `<vault>/.epistemos/prompts`. This is useful, but it becomes privacy-sensitive if prompts include provider keys, hidden capture metadata, attached-note text, or model input snapshots.

Required scans:

```bash
find "$VAULT/.epistemos/prompts" -type f -maxdepth 5 -print
rg "sk-|xoxb-|Bearer |BEGIN PRIVATE KEY|OPENAI|ANTHROPIC|GOOGLE|ACCESS_TOKEN|API_KEY" "$VAULT/.epistemos/prompts"
```

Acceptance:

- Prompt persistence contains no secrets.
- User has retention/export/purge controls if prompts contain private note/chat context.
- Model inputs and hidden capture metadata are not retained indefinitely without user-visible policy.

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

Status: CONFIRMED

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

Status: CONFIRMED AUDIT-GATE GAP

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

### RCA11-P1-004 - Label permissions UI as resource grants, not universal capability control

Status: CONFIRMED SCOPE-LIMITED

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

Status: CONFIRMED HARNESS GAP

Subsystem: `Epistemos-AppStore.xcscheme`, MAS test coverage, release truth.

Research signal: The App Store scheme has an empty `<Testables>` block in the cited audit. The App Store target/build may be real, but its scheme does not by itself run App Store-specific runtime tests.

Patch plan:

- Add App Store target testables where practical.
- Or add a dedicated MAS test plan that runs source guards, artifact scan, UI surface scan, and smoke tests against the MAS-built app.

Acceptance:

- A failing MAS-specific behavior fails CI.
- Release notes do not imply App Store runtime test coverage if the scheme remains empty.

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

Status: CONFIRMED

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

### RCA12-P0-002 - Promote App Store artifact verification to the first release-truth gate

Status: PARTIALLY-FIXED / ARTIFACT-PROOF-MISSING

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

### RCA12-P1-002 - Fix the `.epdoc` slash-image persistence split

Status: CONFIRMED

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

### RCA12-P1-003 - Confirm `/image` command truth mismatch and hide until executable

Status: CONFIRMED

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

Status: PARTIALLY-EVIDENCED / NEEDS-RUNTIME-PROOF

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

Status: focused Wave 0 patch landed / targeted automated proof green / manual runtime A-vault -> reset -> B-vault proof still pending
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

Status: INTAKE / FORENSIC AUDIT REQUIRED BEFORE PRODUCT CODE

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

### UIX-2026-05-09-003 - Notes/sidebar performance regression

Status: PARTIAL FIX LANDED / AUTOMATED SOURCE GUARD GREEN / RUNTIME PROFILE STILL PENDING

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

### UIX-2026-05-09-004 - Fullscreen and cinematic graph quality parity

Status: INTAKE / GRAPH RENDERING QUALITY AUDIT REQUIRED BEFORE PRODUCT CODE

User signal:

- Fullscreen and cinematic graph modes currently look lower quality than the minimized graph.
- Cinematic mode should render at full-quality visual settings.
- Performance mode may intentionally use reduced quality in the high-definition/fullscreen aspect, but that degradation must be explicit to performance mode rather than leaking into cinematic/fullscreen defaults.

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

### UIX-2026-05-09-005 - Graph label hybrid zoom scaling

Status: QUEUED - GRAPH RENDERING PASS AFTER CURRENT P0/P1 RELEASE BLOCKERS

User signal:

- Graph labels currently feel like fixed screen-space HUD labels rather than spatial labels attached to graph nodes.
- Desired behavior is closer to Obsidian's graph: labels should scale with zoom enough to feel graph-space native while remaining crisp and readable.

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
