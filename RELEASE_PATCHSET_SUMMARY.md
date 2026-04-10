# Release Patchset Summary

Date: 2026-04-09

This summary covers the release-engineering changes landed in this audit pass. It is intentionally narrower than the full dirty worktree and only describes the safety, truthfulness, and validation work completed here.

## 1. Release truth and model catalog cleanup

- Removed the dead local model entry `mlx-community/gemma-4-12b-it-4bit`.
- Tightened Mamba2 release claims so it no longer presents as a validated local agent path.
- Updated Mamba2 descriptor copy to say the custom helper runtime warmup is Apple Silicon-only and that generation still runs through MLX.
- Hid `Tool Tier` UI when a model does not actually expose agent mode.

Primary files:

- `Epistemos/State/InferenceState.swift`
- `Epistemos/Engine/LocalModelInfrastructure.swift`
- `Epistemos/Views/Chat/ModelAboutSheet.swift`
- `Epistemos/Views/Settings/CognitiveSettingsSection.swift`

## 2. Attachment and reference prompt contract hardening

- Reworked file attachment context generation to distinguish required context from supplemental context.
- Added explicit reasoning for why each attachment is present.
- Added text-only model guidance for image attachments.
- Wrapped note and chat references in clearer prompt sections so models are instructed to use them when relevant.

Primary file:

- `Epistemos/App/ChatCoordinator.swift`

Primary regression coverage:

- `EpistemosTests/FileAttachmentBuilderTests.swift`
- `EpistemosTests/PipelineServiceTests.swift`

## 3. Code editor release-path simplification

- Added a release policy that disables unfinished editor sidecars by default.
- Hid the semantic sidebar, AI Partner controls, and suggestion surface plumbing unless explicitly re-enabled later.
- Preserved the calmer core editor path instead of leaving noisy partially wired surfaces exposed.

Primary file:

- `Epistemos/Views/Notes/CodeEditorView.swift`

Primary regression coverage:

- `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`

## 4. Mamba / SSM phase-1 hardening

- Added architecture-aware custom SSM runtime support.
- Fixed the universal Release compile blocker caused by direct `Float16` use in the Mamba diagnostic/helper path.
- Kept the real Apple Silicon diagnostic implementation intact.
- Gated the helper diagnostic path off on non-Apple-Silicon slices instead of pretending it works everywhere.

Primary files:

- `Epistemos/Engine/SSMRuntimeProfile.swift`
- `Epistemos/Engine/Mamba2ForwardPass.swift`

Primary regression coverage:

- `EpistemosTests/Mamba2MetalRuntimeTests.swift`
- `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`
- `EpistemosTests/LocalModelInfrastructureTests.swift`

## 5. Omega/Hermes cleanup and release navigation hygiene

- Removed the stale Hermes label from model profile creation copy.
- Sanitized retired Omega navigation paths so release-visible navigation falls back to supported tabs.
- Prevented hidden Omega state from being restored as if it were still a first-class release surface.

Primary files:

- `Epistemos/Views/ModelProfiles/ModelProfileCreationSheet.swift`
- `Epistemos/Models/BrandedTypes.swift`
- `Epistemos/Intents/Custom/NavigationIntents.swift`
- `Epistemos/Intents/Entities/NoteEntity.swift`
- `Epistemos/State/WorkspaceService.swift`

Primary regression coverage:

- `EpistemosTests/AuditFixRegressionTests.swift`
- `EpistemosTests/SDPageQueryDescriptorTests.swift`
- `EpistemosTests/WorkspaceSnapshotTests.swift`

## 6. Production hardening cleanup

- Replaced `try!` regex initializers in `OutlineNavigatorView`.
- Removed force-unwrap hazards in Google auth refresh and hologram node inspection.
- Preserved assistant thinking blocks during Rust-side conversation compaction.

Primary files:

- `Epistemos/Views/Notes/OutlineNavigatorView.swift`
- `Epistemos/Engine/CloudProviderAuthService.swift`
- `Epistemos/Views/Graph/HologramNodeInspector.swift`
- `agent_core/src/compaction.rs`

Primary regression coverage:

- `EpistemosTests/ProductionHardeningTests.swift`
- `EpistemosTests/RuntimeValidationTests.swift`
- `agent_core/src/compaction.rs` unit test `recent_thinking_blocks_survive_compaction`

## 7. Build and test wrapper hardening

- Standardized `scripts/xcodebuild_epistemos.sh` as the supported entry point for Xcode builds/tests in this repo.
- Updated the test and audit scripts to call through that wrapper.
- Documented the transitive SwiftLint plugin problem so validation commands are reproducible.

Primary files:

- `scripts/xcodebuild_epistemos.sh`
- `Makefile`
- `scripts/run_swift_tests.sh`
- `scripts/release/build_release_app.sh`
- `scripts/audit/release_preflight.sh`
- `scripts/audit/verify.sh`
- `TESTING_GUIDE.md`

## 8. Validation outcome for this patchset

- No-sign Release build now passes.
- Direct package resolution now passes and resolves the local `mlx-swift-lm` products before the main build.
- Direct no-sign Debug build now passes after the package refresh, and the user-reported `MLXLMCommon` / `MLXLLM` / `MLXVLM` plus `ChatCoordinator.swift` symbol errors did not reproduce.
- Focused arm64 regression slice passes.
- Focused runtime validation slice passes.
- Focused note-chat and file-attachment regression slice passes.
- Live Mamba2 SSM save/resume still passes.
- Mamba helper runtime warmup remains real on Apple Silicon.
- Mamba agent mode remains hidden until the backend is actually finished end to end.

## 9. Screenshot-driven reliability corrections

- Standard cloud chat no longer routes through the Rust agent path unless the user explicitly selects agent mode.
- Up-front cloud agent runtime failures now throw back to the caller so fallback behavior stays truthful instead of leaving a fake "using standard pipeline" banner behind.
- Workspace summaries are sanitized before persistence and before reuse as prompt context, preventing leaked `<think>` / reasoning dumps from surfacing in welcome-back and session-awareness UI.
- Default workspace-awareness injection is lighter when the user already attached explicit note/chat/file context, reducing prompt dilution on the main chat path.
- Code-file note chat now binds the live code buffer into `NoteChatState`, so "Ask this note" on Swift files sees the actual file content instead of an empty note body.
- Model Vaults settings now report only configured cloud providers plus installed local models, and the rebuild button targets that same truthful scope.
- MLX SSM session reuse is now scoped to the active chat session, reducing recurrent-state bleed between separate Mamba/Liquid conversations.

Primary files:

- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/State/WorkspaceSummaryService.swift`
- `Epistemos/Views/Notes/CodeEditorView.swift`
- `Epistemos/Views/Settings/ModelVaultsSettingsView.swift`
- `Epistemos/KnowledgeFusion/CloudKnowledgeDistillationService.swift`
- `Epistemos/Engine/MLXInferenceService.swift`
- `EpistemosTests/RuntimeValidationTests.swift`

## 10. Late release-facing prompt and picker hardening

- Welcome-back summaries are now sanitized again at restore/display/save time, so stale persisted reasoning artifacts cannot leak back into the landing overlay or exported session-summary notes.
- Main chat now adds an explicit required-context contract when the user attached files or referenced notes/chats, and it stops auto-injecting workspace background when that explicit context is already present.
- Note chat now treats the live note buffer as the primary document on all submit paths instead of only the toolbar path.
- The code editor release path now keeps only the focused ask-bar mode visible, removing the still-misaligned inline annotation mode from the active release flow.
- Release-facing local-model pickers and Model Vault targets now filter to locally installed models that have not already failed the April 8 live validation sweep.
- Manage Local Models still shows those hidden models, but now explains why they are not exposed in the active release picker.
- Shared user-facing output cleanup now strips orphan `</think>` / `</thinking>` closers and the leaked reasoning prelude ahead of them, which closes the screenshot-reproduced dump path in chat transcripts and welcome-back summaries.

Primary files:

- `Epistemos/State/WorkspaceService.swift`
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/Views/Landing/LandingView.swift`
- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/State/NoteChatState.swift`
- `Epistemos/Views/Notes/CodeEditorView.swift`
- `Epistemos/Views/Notes/InlineResponseHighlighter.swift`
- `Epistemos/State/InferenceState.swift`
- `Epistemos/Engine/LocalModelInfrastructure.swift`
- `Epistemos/Views/Settings/SettingsView.swift`
- `Epistemos/App/RootView.swift`
- `Epistemos/Views/Settings/ModelVaultsSettingsView.swift`
- `Epistemos/Engine/Extensions.swift`
- `EpistemosTests/FileAttachmentBuilderTests.swift`
- `EpistemosTests/RuntimeValidationTests.swift`
- `EpistemosTests/LocalModelInfrastructureTests.swift`
- `EpistemosTests/UserFacingModelOutputTests.swift`

## 11. April 9 package, fallback, and harness hardening

- Fixed the constrained 18GB recommendation ladder so interactive chat fallbacks no longer point at quarantined `Qwen 3.5 9B`.
- Kept Prism Bonsai 8B out of the installable catalog because the pinned `mlx-swift-lm` fork still lacks the real Prism 1-bit runtime path.
- Added a live-validation blocker classifier for Hugging Face `429` install failures so the harness now surfaces that condition as a concise external blocker instead of dumping raw HTML noise.
- Taught `scripts/xcodebuild_epistemos.sh` to pre-resolve Swift packages before normal build/test invocations.
- Added stale DerivedData `Epistemos.app` cleanup to the wrapper so local-model sweep reruns no longer start from obviously orphaned test-app state.
- Added `ReleaseScriptAuditTests` coverage for both wrapper hardening paths and extended `LocalModelInfrastructureTests` coverage for constrained fallback truth plus Bonsai gating.

Primary files:

- `Epistemos/State/InferenceState.swift`
- `EpistemosTests/LocalModelInfrastructureTests.swift`
- `EpistemosTests/LocalRuntimeSmokeSupport.swift`
- `EpistemosTests/ReleaseScriptAuditTests.swift`
- `scripts/xcodebuild_epistemos.sh`

Validation outcome:

- `xcodebuild -project Epistemos.xcodeproj -resolvePackageDependencies` passed on 2026-04-09.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO` passed on 2026-04-09.
- `bash -n scripts/xcodebuild_epistemos.sh` passed on 2026-04-09.
- `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-release-audit-2 test CODE_SIGNING_ALLOWED=NO -only-testing:EpistemosTests/LocalModelInfrastructureTests -only-testing:EpistemosTests/ReleaseScriptAuditTests` passed on 2026-04-09 with 43 tests in 2 suites once the live LFM/Mamba SSM sentinel files were temporarily masked and restored.
- A separate April 9 live SSM rerun with those sentinels armed was blocked by Hugging Face `429` rate limits during reinstall attempts for Liquid 350M and Mamba2, so fresh live revalidation for those two models remains blocked externally.

## Scope note

This patchset makes the release path safer and more honest, but it does not claim that all remaining product-level release validation is finished. The missing full model sweep, cloud validation, graph feel pass, and packaging steps remain documented blockers in `RELEASE_READINESS_AUDIT.md`.
