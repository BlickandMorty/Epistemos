# Codex Terminal Prompt: Epistemos Recursive Fix Pass

Use this prompt in the Codex terminal agent from the repository root:

```text
You are Codex working in /Users/jojo/Downloads/Epistemos.

Mission:
Perform a recursive, release-grade fix pass over Epistemos using the audit backlog as the source of truth. Do not build new product architecture or new "brain" features until the current-app P0/P1 release blockers are fixed, tested, manually/runtime-verified where required, and checked off in the backlog.

Latest priority update:
The active user blocker is now vault lifecycle truth: the app currently fails the user-facing flow where Reset Everything should clear stale Notes/sidebar/Graph state and allow selecting a new vault cleanly. Start with that live bug before CodeFileService containment. Treat vault reset/add/remove as a P0 product trust issue because stale notes after reset make the app look possessed by old state and make vault selection unreliable.

Absolute rules:
1. Read AGENTS.md first and obey it.
2. Read docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md before coding, then read the directly relevant canon/source files for the subsystem you touch.
3. Read docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md before coding. Treat Research Drops 9-13 as the current implementation order.
4. Do not touch ~/Epistemos-RETRO/, src-tauri/, or ~/meta-analytical-pfc/.
5. Do not implement Helios/Lean/theorem/future-brain features yet. Park AnswerPacket, ClaimGraph, RuntimeInvariant, Metal kernels, and falsifier harness work until the current-app blockers are closed.
6. Do not trust docs, source guards, or registries as runtime proof. Every ship claim needs source proof, caller chain, user surface, side effect/persistence path, tests, logs/runtime/manual proof, and build/target proof where applicable.
7. Test-first for each fix. Add a failing focused test before changing product code unless the change is docs/script-only.
8. Use minimal fixes. Do not refactor adjacent code unless it is required to fix the bug safely.
9. Never revert user changes. Inspect git status before and after each fix.
10. Keep the audit log updated after every closed item with exact evidence, commands, and remaining risk.

Primary backlog file:
docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md

Supporting audit/canon files to read as needed:
- docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
- docs/KNOWN_ISSUES_REGISTER.md
- docs/audits/V1_RELEASE_AUDIT_2026_05_07.md
- docs/audits/V1_DEEP_INTERACTION_AUDIT_2026_05_08.md
- docs/audits/PERFORMANCE_CONCURRENCY_AUDIT.md
- docs/audits/PRIVACY_APP_STORE_AUDIT.md
- docs/audits/USER_WIRING_CAPABILITY_MAP.md
- docs/audits/DATA_PERSISTENCE_INDEXING_AUDIT.md
- docs/audits/PRE_HELIOS_FEATURE_AUDIT_2026_05_06.md
- docs/audits/CODEX_RECURSIVE_FIX_PROMPT_2026_05_09.md
- docs/CLI_CONFIG_COMPILATION_RESEARCH.md
- docs/future-work-audit.md

If using packets instead of live source, prioritize:
- docs/audits/codebase-verbatim-packets-2026-05-09/00_INDEX.md
- docs/audits/codebase-verbatim-packets-2026-05-09/01_CODE_PACKET.md
- docs/audits/codebase-verbatim-packets-2026-05-09/02_CODE_PACKET.md
- docs/audits/codebase-verbatim-packets-2026-05-09/03_CODE_PACKET.md
- docs/audits/codebase-verbatim-packets-2026-05-09/04_CODE_PACKET.md
- docs/audits/codebase-verbatim-packets-2026-05-09/05_CODE_PACKET.md
- docs/audits/codebase-verbatim-packets-2026-05-09/06_CODE_PACKET.md
- docs/audits/codebase-verbatim-packets-2026-05-09/07_CODE_PACKET.md
- docs/audits/codebase-verbatim-packets-2026-05-09/08_CODE_PACKET.md
- docs/audits/codebase-verbatim-packets-2026-05-09/09_CODE_PACKET.md
- docs/audits/codebase-verbatim-packets-2026-05-09/10_CODE_PACKET.md
- docs/audits/codebase-verbatim-packets-2026-05-09/11_CODE_PACKET.md

Phase 0: repo reality and evidence map
1. Run:
   git status --short
   git branch --show-current
   git rev-parse --short HEAD
2. Read AGENTS.md.
3. Read the backlog sections:
   - Research Drop 9 Integrated Fix-Pass Addendum
   - Research Drop 10 Integrated Verification-Pass Addendum
   - Research Drop 11 Integrated Current-App Release-Truth Addendum
   - Research Drop 12 Integrated Pre-Fix Orchestration Addendum
   - Research Drop 13 Finalization and Live-Vault Blocker Addendum
4. Create a working issue matrix in your notes with:
   ID, source files, status, planned tests, patch files, commands run, runtime/manual checks, result, next blocker.
5. Do not start future architecture. The current-app P0/P1 fixes below come first.

Required fix order:

P0 Wave 0: live vault lifecycle blocker
0. Harden vault reset, add, remove, and selection.
   User symptom:
   - app will not let the user choose a vault reliably
   - Notes sidebar and Graph still show old notes after Settings -> Reset Everything
   - reset appears to run but does not actually produce a clean first-run/vaultless state
   Files to inspect first:
   - Epistemos/App/AppBootstrap.swift
   - Epistemos/App/RootView.swift
   - Epistemos/Views/Settings/SettingsView.swift
   - Epistemos/Views/Onboarding/SetupAssistantView.swift
   - Epistemos/Views/Sidebar/VaultSelectorView.swift
   - Epistemos/Vault/VaultRegistry.swift
   - Epistemos/Sync/VaultSyncService.swift
   - Epistemos/Sync/NoteFileStorage.swift
   - Epistemos/Sync/SearchIndexService.swift
   - Epistemos/Graph/GraphState.swift
   - Epistemos/Graph/GraphStore.swift
   - Epistemos/Engine/ShadowSearchService.swift
   - Epistemos/Engine/HaloController.swift
   - Epistemos/State/NotesUIState.swift
   - Epistemos/Views/Notes/NotesSidebar.swift
   - any SwiftData reset helpers and app-support derived stores
   Starting evidence:
   - `AppBootstrap.resetAllData()` stops vault watching, clears persisted vault selection, wipes SwiftData models, removes managed note bodies, resets Notes UI, sets setup mode, and marks graph as needing refresh.
   - That is not enough if the graph store/engine, search/Shadow/Halo indexes, sidebar query rows, vault registry/bookmarks, restored workspaces, or background tasks still publish stale state.
   Required tests:
   - Reset Everything deletes/clears all SwiftData note/folder/chat/block/graph rows in the active context.
   - Reset Everything clears `NoteFileStorage` managed bodies and any Application Support derived note/search/graph stores.
   - Reset Everything clears graph store + engine-visible nodes, not only `needsRefresh`.
   - Reset Everything clears search/readable-block/Shadow/Halo/Instant Recall derived indexes or marks them unavailable until a new vault is selected.
   - Reset Everything clears persisted vault selection/bookmark state and revokes/stops access cleanly.
   - After reset, Notes sidebar is empty, Graph is empty/vaultless, Search/Halo show no stale old-note hits, Settings says no vault connected, and setup can choose a fresh vault.
   - Selecting vault A imports/shows only vault A. Removing/disconnecting vault A clears A from Notes/Search/Graph/Halo. Selecting vault B after that shows only B.
   - Failed vault selection does not destroy the previous valid vault state unless the user explicitly reset/disconnected.
   Manual/runtime proof:
   - Create disposable vault A with unique note `VAULT_A_ONLY`.
   - Select/import A, confirm Notes/Search/Graph/Halo/Settings agree.
   - Run Reset Everything from Settings.
   - Confirm `VAULT_A_ONLY` disappears from Notes sidebar, Graph, Search, Halo diagnostics, and any restored workspace without relaunch if possible, and after relaunch always.
   - Choose disposable vault B with unique note `VAULT_B_ONLY`.
   - Confirm only B appears.
   Acceptance:
   - one canonical active-vault truth object/event drives Notes, Settings, Graph, Search, Halo, and onboarding
   - destructive reset is idempotent and logs every cleared subsystem
   - add/remove/disconnect/select are transactional and visibly fail if any required phase fails
   - no stale note can appear while Settings says no vault connected, unless it is explicitly labeled disconnected cache and cannot be edited/synced as live data

P0/P1 Wave 1: filesystem and persistence trust
1. CodeFileService containment.
   Files:
   - Epistemos/Engine/CodeFileService.swift
   - Epistemos/Models/CodeArtifactSidecar.swift
   - EpistemosTests/CodeFileServiceTests.swift
   - any CodeSidecarPath file/type
   - Epistemos/Engine/LiveCodeEditorController.swift
   - Epistemos/Views/Notes/NoteDetailWorkspaceView.swift
   Required tests:
   - create rejects relativeDirectory "../outside"
   - create rejects relativeDirectory "/tmp"
   - read rejects external absolute URL
   - update rejects external absolute URL and preserves outside file
   - symlink inside vault pointing outside is rejected
   - prefix collision outside vault is rejected
   - .epcache spoofing is rejected
   - agent/tool-originated write without grant is rejected if that path is reachable
   Focused command:
   xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CodeFileServiceTests test CODE_SIGNING_ALLOWED=NO
   Acceptance:
   - every create/read/update/list/sidecar path goes through one canonical vault containment resolver
   - no arbitrary URL can be read or written
   - no sidecar is created for rejected paths
   - visible code editor paths cannot bypass containment

2. Database fallback degraded mode.
   Files:
   - Epistemos/App/AppBootstrap.swift
   - Epistemos/App/EpistemosApp.swift
   - Epistemos/App/RootView.swift
   - SwiftData model/container setup files
   Required behavior:
   - no "Continue Empty" normal-looking editable mode
   - recovery-only or explicit temporary scratch session
   - persistent banner if non-durable
   - ordinary note/chat/capture/.epdoc/vault writes blocked or clearly temporary/export-only
   Tests:
   - injected ModelContainer open failure
   - degraded mode blocks or labels writes
   - relaunch does not imply temporary data was durable

3. Direct code-file SwiftUI IO removal.
   Files:
   - Epistemos/Views/Notes/NoteDetailWorkspaceView.swift
   - Epistemos/Views/Notes/CodeEditorView.swift
   - Epistemos/Engine/LiveCodeEditorController.swift
   - Epistemos/Engine/CodeFileService.swift
   Tests:
   - view body construction does not touch disk
   - large code-file switch does not read on main thread
   - visible code save uses CodeFileService
   - write failure does not create false SwiftData success

P0/P1 Wave 2: credentials, auth, and privacy
4. Remove or scope provider credential environment mirroring.
   Files:
   - Epistemos/App/AppBootstrap.swift
   - Epistemos/Engine/CloudProviderAuthService.swift
   - all Process/NSTask/posix_spawn wrappers
   - agent_core provider bridge files
   Greps:
   rg -n "Process\\(|NSTask\\(|posix_spawn|Command::new|std::process|setenv\\(|unsetenv\\(|environment =" Epistemos agent_core omega-mcp omega-ax
   rg -n "OPENAI_|ANTHROPIC_|GOOGLE_|ACCESS_TOKEN|API_KEY|HF_TOKEN" Epistemos agent_core omega-mcp omega-ax
   Acceptance:
   - no user provider secret is mirrored into parent process env by default
   - every child process uses a scrubbed environment
   - fake secret env probe proves no helper inherits secrets unexpectedly

5. Harden OAuth callback.
   Files:
   - Epistemos/Engine/CloudProviderAuthService.swift
   - any LocalOAuthCallbackServer helper
   Tests:
   - missing state rejected
   - wrong state rejected
   - replayed state rejected
   - wrong path rejected
   - wrong host rejected
   - concurrent sign-ins isolated
   Acceptance:
   - loopback-only bind
   - one-time state
   - PKCE verifier tied to state/session

6. Remove hidden capture/audio metadata from note bodies.
   Files:
   - Epistemos/Engine/TextCapturePipeline.swift
   - Epistemos/Views/Capture/QuickCaptureView.swift
   - Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift
   - export/share/sync paths
   Tests:
   - capture text body has no capture-provenance HTML comment
   - audio capture body has no audio-source HTML comment
   - export/share/search index omit hidden metadata by default
   - migration strips legacy hidden comments while preserving structured provenance

7. Composer voice temp cleanup.
   Files:
   - Epistemos/Engine/ComposerVoiceInputService.swift
   - Epistemos/Views/Chat/VoiceInputButton.swift
   - Epistemos/Views/Chat/ChatInputBar.swift
   Tests:
   - success deletes composer-*.m4a
   - transcription error deletes composer-*.m4a
   - cancel deletes composer-*.m4a
   - window close / teardown deletes composer-*.m4a
   Manual:
   find "${TMPDIR:-/tmp}" -name 'composer-*.m4a' -print

P0/P1 Wave 3: App Store, tool truth, and current access
8. App Store artifact scan and MAS scheme proof.
   Files:
   - Epistemos.xcodeproj/project.pbxproj
   - Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-AppStore.xcscheme
   - Epistemos-AppStore-Info.plist
   - Epistemos-Info.plist
   - Tools/app-review-audit/app-review-audit.sh
   - build-agent-core.sh
   - build-omega-mcp.sh
   - bundle-app-runtime-assets.sh
   Required:
   - MAS scheme has non-empty test/smoke plan or dedicated MAS CI job
   - app-review audit fails MAS-reachable subprocess findings
   - artifact scan inspects final .app strings, symbols, dylibs, executables, resources
   Commands:
   xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Release -destination 'platform=macOS' build
   find "$APP" -type f -print0 | xargs -0 strings 2>/dev/null | rg "pty|osascript|cli_passthrough|bash_execute|Command::new|fork|exec|docker|stdio_mcp|ScreenCaptureKit|AXUIElement|/bin/sh|/bin/bash|launchctl"

9. Current Access runtime parity.
   Files:
   - Epistemos/Views/Chat/ChatInputBar.swift
   - Epistemos/App/ChatCoordinator.swift
   - Epistemos/Bridge/ToolTierBridge.swift
   - Epistemos/State/AgentCommandCenterState.swift
   - agent_core/src/tools/registry.rs
   - agent_core/src/permissions.rs
   - agent_core/src/resources/bridge.rs
   Tests:
   - visible chip equals compiled allowed resource/tool plan
   - attached file A does not allow file B write
   - attached note A does not allow note B write
   - snapshot attachment cannot be mutated
   - resource grants UI is labeled as resource grants, not universal capability control

10. Command/tool truth and /image.
   Files:
   - Epistemos/State/AgentCommandCenterState.swift
   - Epistemos/Views/Chat/SlashCommandPopover.swift
   - Epistemos/Engine/MLXImageGenerationService.swift
   - agent_core/src/tools/registry.rs
   - js-editor/src/extensions/slash-menu.ts
   - js-editor/src/extensions/image-asset-bridge.ts
   Required:
   - /image hidden unless a backend can execute
   - .epdoc slash image uses package-local asset bridge, not remote URL prompt by default
   - generated command/tool truth table: advertised -> parsed -> compiled -> approved -> executed -> logged -> visible

P1 Wave 4: editor, epdoc, search, graph, vault
11. .epdoc hot paths.
   Files:
   - Epistemos/Engine/EpdocEditorBridge.swift
   - Epistemos/Engine/EpdocDocument.swift
   - Epistemos/Engine/EpdocGraphProjector.swift
   Required:
   - URL scheme asset reads/Brotli off main actor
   - autosave/projection/index/graph churn coalesced
   - save/reopen/projection smoke passes

12. Prose editor parsing hot path.
   Files:
   - Epistemos/Views/Notes/ProseTextView2.swift
   - Epistemos/Views/Notes/MarkdownContentStorage.swift
   Required:
   - no full-structure parse per keystroke in large docs
   - stale background parse ignored

13. Query/search/Halo main actor and failure truth.
   Files:
   - Epistemos/Engine/QueryEngine.swift
   - Epistemos/Engine/QueryRuntime.swift
   - Epistemos/Engine/RetrievalRuntime.swift
   - Epistemos/Engine/ShadowSearchService.swift
   - Epistemos/Engine/HaloController.swift
   - Epistemos/Sync/SearchIndexService.swift
   Required:
   - heavy retrieval/reranking off main
   - Shadow backend failure is visible degraded state, not empty hits

14. Vault Organizer transactional safety.
   Files:
   - Epistemos/Views/Notes/VaultOrganizerView.swift
   - Epistemos/Sync/VaultSyncService.swift
   - Epistemos/Models/SDPage.swift
   - Epistemos/Models/SDFolder.swift
   Required:
   - DB/filesystem move/create are transactional or rolled back
   - failure and cancellation are visible and do not publish stale success

15. Graph truth and performance.
   Files:
   - Epistemos/Graph/GraphState.swift
   - Epistemos/Graph/FilterEngine.swift
   - Epistemos/Graph/SDFLabelInstanceBuilder.swift
   - Epistemos/Views/Graph/MetalGraphView.swift
   - graph-engine/src/renderer.rs
   - graph-engine/src/physics.rs
   Required:
   - filter/search/model/vault state affects actual render payload
   - SDF label budget enforced
   - connected-vault create/rename/move/delete converges across Notes/Search/Graph/Halo/Settings
   - fullscreen graph p95/p99 profiled

P2 Wave 5: harness truth
16. Fix run_all_tests and perf gates.
   Files:
   - scripts/run_all_tests.sh
   - scripts/check-perf-budgets.sh
   Required:
   - run_all_tests either renamed or truly expanded
   - release perf mode fails if runtime measurement JSON is absent
   - source guards, unit tests, integration tests, runtime smoke, artifact scans reported separately

17. Quarantine scaffolds and future architecture.
   Files to inspect:
   - Epistemos/Views/Graph/GraphInspectModeView.swift
   - Epistemos/Engine/ANEBackend.swift
   - Provider XPC/streaming mock files
   - retired Omega/Hermes files
   - any AnswerPacket/VRM files
   Required:
   - unmounted/deferred surfaces cannot appear in product feature inventory
   - no AnswerPacket/ClaimGraph/RuntimeInvariant/Metal kernel implementation until P0/P1 current-app gates are closed

P2/P3 Wave 6: post-blocker usability lanes, design-first
18. Dynamic CLI discovery and install prompts.
   Do not start until Wave 0 and Wave 1 security/persistence blockers are green.
   Files to inspect:
   - agent_core/src/tools/cli_passthrough.rs
   - agent_core/src/tools/registry.rs
   - Epistemos/Bridge/ToolTierBridge.swift
   - Epistemos/Views/Settings/AgentControlSettingsView.swift
   - Epistemos/State/AgentCommandCenterState.swift
   - Epistemos/State/InferenceState.swift
   - Epistemos/AppStore/AppStoreComputerUseStubs.swift
   - docs/CLI_CONFIG_COMPILATION_RESEARCH.md
   Required:
   - direct/Pro builds may detect installed `codex`, `claude`, `gemini`, `kimi`, and related agent CLIs from a scrubbed environment
   - App Store builds hide or hard-deny this surface
   - detection never executes untrusted commands beyond explicit version/probe calls through a scrubbed allowlisted environment
   - missing CLIs produce an install/setup prompt, never silent installation
   - exact install commands/links must be verified against current official vendor docs at implementation time
   - secrets are not pulled from parent process env; auth/import paths use scoped stores
   Tests:
   - fake PATH with stub binaries proves installed/missing/version states
   - MAS build has no visible CLI setup affordance
   - absent CLI denies execution with helpful setup copy
   - installed CLI handshake produces a capability row, not unrestricted execution

19. Local Engineering Agent structure.
   Do not implement an open network port by default. Design first, then gate behind Pro/developer settings if ever needed.
   Files to inspect:
   - Epistemos/LocalAgent/LocalAgentLoop.swift
   - Epistemos/LocalAgent/LocalAgentPromptBuilder.swift
   - Epistemos/LocalAgent/LocalAgentCommandDispatcher.swift
   - Epistemos/Bridge/ToolTierBridge.swift
   - Epistemos/App/ChatCoordinator.swift
   - agent_core/src/session.rs
   - agent_core/src/tools/registry.rs
   Required design:
   - app-native engineering agent with visible plan, logs, allowed tools, patch proposals, checkpoints, rollback, and verification loop
   - local loopback/API surface, if added, is disabled by default, bound to localhost only, token-authenticated, logged, and unavailable in MAS
   - no raw "open code port" that lets outside processes mutate the app/repo without scoped authorization
   - keep it expressive and useful, but make every capability visible and revocable

Verification loop:
After each fix:
1. Run focused tests for the touched subsystem.
2. Run relevant greps/source guards.
3. Update docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md with:
   - exact files changed
   - exact tests added
   - exact commands run
   - result
   - remaining runtime/manual proof
4. If the fix affects a release-risk surface, run a manual/runtime smoke or mark it explicitly blocked.

After a wave is complete:
1. Run:
   xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
   xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test
   cargo test --manifest-path graph-engine/Cargo.toml
   cargo test --manifest-path agent_core/Cargo.toml
   cargo test --manifest-path omega-mcp/Cargo.toml
2. Run the MAS build/artifact scan if any App Store gating changed.
3. Inspect logs. A manual smoke is not verified until logs agree with UI behavior.
4. If any failure or new issue appears, fix it and reset the clean-pass counter.

Final success condition:
Do not claim release-ready until there are 3 uninterrupted clean passes with no code changes between passes. Each pass must include automated checks, source/log audit, and manual/runtime spot checks for the ship-risk surfaces listed above.

Final report must say one of:
- READY FOR DIRECT RELEASE
- READY FOR DIRECT RELEASE, MAS LITE ONLY
- NOT READY

Start now with Phase 0, then Wave 0: vault reset/add/remove/selection hardening only. Do not touch CLI discovery, local-agent shell design, UI polish, graph renderer optimization, Omega, Helios, or future-brain files until the live vault blocker is fixed and verified. After Wave 0 is green, move to Wave 1 item 1: CodeFileService containment.
```
