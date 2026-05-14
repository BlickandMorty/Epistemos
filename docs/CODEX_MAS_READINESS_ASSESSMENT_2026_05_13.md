# Codex MAS Readiness Assessment - 2026-05-13 Handoff

Supersession note, 2026-05-14: this document is retained as the historical no-go assessment and evidence source for the final v1 recursive release audit. Several blockers recorded here have since been fixed or reclassified in `docs/CODEX_V1_FINAL_RECURSIVE_RELEASE_AUDIT_2026_05_14.md`; treat that final audit as the current status authority.

Assessment run: 2026-05-14 on branch `codex/research-snapshot-2026-05-08`.

Verdict: **NO-GO for MAS submission.** The chat-tool-parity commits are structurally present, and the narrow MAS leak scans from the handoff pass, but the branch is not release-ready because the Swift test target does not compile, the stronger App Store artifact scanner fails on a clean isolated build, the `.epdoc` Brotli fix emits a Swift 6 data-race warning, live App Store smoke cannot reach the UI cleanly against the local runtime store, and an operator crash now reproduces the previously deferred background SwiftData relationship-access failure in the App Store bundle.

## What I Verified

- Used the release-audit workflow in `.agents/skills/epistemos_release_audit/SKILL.md`.
- Read the local canon entrypoint `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`, the handoff, the MAS release manifest, V6.2 progress/canon docs, `CODEX_RECURSIVE_FIX_PROMPT_2026_05_09.md`, and the audit register.
- Verified the four handoff commits exist and only touch the claimed files:
  - `951a74c38`: `Epistemos/Views/Chat/ChatInputBar.swift`
  - `3a43066df`: `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
  - `f5f50d0ac`: `Epistemos/Views/Graph/HologramSearchSidebar.swift`
  - `9b74c615d`: deletes `Epistemos/Views/Notes/TransclusionOverlayView.swift`
- Verified the graph-protected patch is scoped to `HologramSearchSidebar.sendGraphChatMessage()` and `graphNodeContextAttachment`; I did not edit graph rendering, Metal, layout, edge geometry, or hologram visuals.
- Verified `CloudModelProvider.supportsAgentTier` is OpenAI/Anthropic only (`Epistemos/State/InferenceState.swift:1204`) and native cloud tool preferences default true (`Epistemos/State/InferenceState.swift:3286`).
- Verified V6.2 substrate observers are called in `sampleTurnBucket` (`Epistemos/Engine/InterruptScoreCpu.swift:272`).
- Verified Rust subprocess hardening coverage by grepping every `Command::new` under `agent_core/src`; all production launch sites either call `harden_cli_subprocess`, `harden_cli_subprocess_extending`, or perform local env-clearing hardening in `terminal.rs`.

## Automated Results

- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`: **build succeeded**, but Xcode still prints non-fatal SwiftLint script-phase failures for CodeEdit package targets.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO`: **build succeeded** with the same non-fatal SwiftLint script-phase lines.
- Isolated App Store build: `xcodebuild ... -derivedDataPath /tmp/EpistemosAppStoreAuditDD ...`: **build succeeded**, and reproduced the Swift 6 warning at `Epistemos/Engine/EpdocEditorBridge.swift:261`.
- `swift test`: **invalid for this repo** (`Package.swift` is absent). The handoff command should be replaced with Xcode test commands.
- Focused Xcode test: `xcodebuild ... -only-testing:EpistemosTests/SDPageQueryDescriptorTests/ExtractionAndMessageRegressionTests/extractionResultDecodesWithoutSources test CODE_SIGNING_ALLOWED=NO -quiet`: **failed to compile**. The blocker is `EpistemosTests/SDPageQueryDescriptorTests.swift:453`, where `decoded.tags.map(\.name)` is mapping the optional array itself rather than `decoded.tags?.map(\.name)`.
- `cargo test --manifest-path agent_core/Cargo.toml --lib`: **1089 passed, 0 failed**.
- `cargo test --manifest-path epistemos-research/Cargo.toml --features research`: **492 unit tests + 113 canonical consistency tests passed**.

## MAS Artifact Evidence

- Clean isolated bundle id: `com.epistemos.appstore`.
- Handoff narrow string scan against `/tmp/EpistemosAppStoreAuditDD/Build/Products/Debug/Epistemos.app`: **zero matches**.
- Handoff narrow `nm -gU` scan of `libagent_core.dylib`: **zero matches**.
- Stronger manifest scanner `scripts/scan_appstore_bundle.sh` against the isolated App Store bundle: **FAILED**.
  - `build/codex-appstore-audit-isolated/forbidden-strings.txt`: `bash_execute`, `docker`.
  - `build/codex-appstore-audit-isolated/forbidden-symbols.txt`: exported std process `posix_spawn` symbols.
  - No prohibited research/tool resource residue in the isolated scan.
- Initial shared-DerivedData App Store launch logged a direct-profile fatal error, but that run was polluted by concurrent Xcode test activity in the same product directory. The isolated App Store launch did not repeat that fatal; it instead surfaced runtime store errors below.

## Live Smoke

Computer Use was attempted against the freshly built app. The UI smoke could not proceed reliably:

- `get_app_state("Epistemos")` timed out.
- Isolated App Store launch logs show repeated CoreData/SwiftData failures for the local store:
  - `no such column: t0.ZWIKILINKREFERENCESCANSIGNATURE`
  - database path: `/Users/jojo/Library/Application Support/Epistemos/default.store`
- I did not mutate the vault or reset the database. This is a vault-sensitive release blocker and should be handled as a migration/recovery issue with a clear rationale before touching user data.
- Because the app UI was not reachable cleanly, I did not complete the requested chat, note ask-bar, or graph before/after pixel smoke. No graph rendering files were changed during this pass.

Additional operator crash evidence added after the first assessment draft:

- Bundle: `com.epistemos.appstore` (MAS scheme, sandboxed).
- Signal: `EXC_BREAKPOINT (SIGTRAP)` from `Swift._assertionFailure` inside SwiftData, on dispatch queue `NSManagedObjectContext 0xbc7a9f780`.
- Crash chain: `SDPage.tags.getter` -> `VaultIndexActor.allPagesForRebuild()` (`Epistemos/Sync/VaultIndexActor.swift:2081`) -> `VaultSyncService.rebuildInstantRecallIndex(from:)` (`Epistemos/Sync/VaultSyncService.swift:2816`) -> detached utility task from `scheduleInstantRecallIndexRebuild` (`Epistemos/Sync/VaultSyncService.swift:2761`).
- Concurrent main-thread chain: `NotesSidebar.rebuildCache()` was rebuilding sidebar folder state around `Epistemos/Views/Notes/NotesSidebar.swift:686`, triggered by `scheduleDeferredRebuild` around `Epistemos/Views/Notes/NotesSidebar.swift:1433`.
- The accessed persisted property is `SDPage.tags: [String]` (`Epistemos/Models/SDPage.swift:34`).
- This matches `RCA8-P0-003`, which was previously deferred waiting for a runtime reproducer. I promoted it to `REOPENED-2026-05-14` in the audit register.
- This crash is not graph, Metal, Rust agent_core, memory pressure, or any of the four chat-tool-parity commits.

## Audit Register Sample

Sampled 10 PATCHED items, plus the newly supplied `RCA8-P0-003` crash reproducer:

1. `RCA-P1-005`: PASS structural. `ChatCoordinator` resolves `effectiveChatSurfaceSelection` and routes tool-capable cloud turns through `runRustAgentPath` (`Epistemos/App/ChatCoordinator.swift:1842`, `:2328`).
2. `RCA2-P0-002`: PASS structural, test execution blocked. `CodeFileService` has containment errors and async read/update helpers (`Epistemos/Engine/CodeFileService.swift:40`, `:51`, `:93`), but Xcode tests cannot compile.
3. `RCA-P2-011`: PASS structural. Graph inspector chat escalation is only in `HologramSearchSidebar.swift:951`; graph renderer/layout files were untouched.
4. `RCA2-P1-014`: PASS source shape, manual smoke pending. `/image` remains governed by command availability docs; runtime command smoke blocked by app launch/test issues.
5. `RCA8-P0-002`: PASS structural. MAS forbidden tools and bounded mutation allowlist are present (`agent_core/src/tools/registry.rs:42`, `:59`); `Command::new` production sites are hardened.
6. `RCA8-P0-003`: **REOPENED**. The operator crash reproduces the previously deferred SwiftData relationship-access risk through `SDPage.tags` during a detached instant-recall rebuild, concurrent with sidebar cache rebuilding.
7. `RCA8-P1-004`: **REOPENED**. The off-main Brotli patch exists, but Swift warns the detached closure captures main actor-isolated `urlSchemeTask` (`Epistemos/Engine/EpdocEditorBridge.swift:261`).
8. `RCA4-P1-011`: PASS structural. AnswerPacket production and `VRMLabelView` binding are wired (`Epistemos/Views/Chat/MessageBubble.swift:474`, `agent_core/src/bridge.rs:3213`).
9. `RCA2-P2-010`: PASS production path, stale evidence remains. `EditableTransclusionView` is live, but grep still finds stale generated/training references and `EpistemosTests/NonAgentPruningValidationTests.swift:354` references the deleted file.
10. `RCA9-P0-002`: **REOPENED**. The isolated App Store artifact scanner fails despite the two narrow leak scans passing.
11. `RCA12-P0-002`: **REOPENED**. Same isolated artifact failure; manual MAS UI sweep is also blocked by runtime store errors.

Sampled 3 PATCHED PARTIAL items:

- `RCA-P0-001`: Remains partial. The live smoke hit a real local store schema error, so recovery/migration proof is still needed.
- `RCA2-P1-008`: Remains partial. The state-flip-before-work pattern is documented, but true off-main retrieval remains a structural refactor and could not be smoke-tested.
- `UIX-2026-05-09-004` / `UIX-2026-05-09-006`: Remain partial. Graph runtime smoke is still pending because the app UI was not reachable; graph remains protected.

Sampled 2 OBSOLETE items:

- `RCA7-P1-009`: Holds. `rg` finds no `HermesExpertMode`, `HermesBrand`, or `HermesShimmeringSigil` production matches.
- `RCA8-P1-002`: Holds for production code. `~/.omega`, `omega_store`, `omega_query`, and `omega doctor` matches are audit docs only, not production Swift/Rust.

## Chat-Tool-Parity Red Team

- The note ask-bar and graph inspector now classify `.agent` / `.research` and escalate to main chat with context attachments (`NoteDetailWorkspaceView.swift:1923`, `HologramSearchSidebar.swift:951`).
- No cyclic escalation path found: `MainChatSubmissionRouter.submit` enters `ChatState.submitQuery` and `ChatCoordinator.handleQuery`; it does not re-enter the note or graph inline submitter.
- Non-note graph nodes return nil context attachment and still submit the query, as intended (`HologramSearchSidebar.swift:1022`).
- Classifier misses remain. Phrases like `is there a doc about X`, `what's the gist of my notes on Y`, and `anything in my vault about X` do not clearly trip the current `agentSignals` list (`ChatCapability.swift:181`). Per handoff, I did not widen heuristics inline.

## Finalization Plan Check

The five-step finalization plan is still directionally correct, but it needs a new step zero:

0. Close the reopened release gates above, including the reproduced `RCA8-P0-003` SwiftData/vault lifecycle crash, and restore a compiling Swift test target.
1. Manual smoke pass on PATCHED PARTIAL risks.
2. App Store CI smoke: App Store scheme builds and passes tests under MAS entitlements.
3. MAS binary submission through Xcode Organizer/App Store Connect.
4. AI disclaimer audit across light/dark and all chat tiers.
5. Pro release after MAS reviewer feedback.

Official Apple references used for the distribution posture: [App Sandbox](https://developer.apple.com/documentation/security/app_sandbox) and [Uploading builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/).

## Recommendation

**No-go.** The next minimal release-readiness pass should fix only the release gates: Swift test compile, isolated App Store artifact scan, `.epdoc` concurrency warning, live store migration/recovery, and the reproduced `RCA8-P0-003` SwiftData/vault lifecycle crash. After those pass, rerun the exact isolated build/scans and then do the manual UI smoke, especially graph and vault, without touching graph rendering unless a concrete rendering bug is reproduced.
