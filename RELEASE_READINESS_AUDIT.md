# Release Readiness Audit

Date: 2026-04-09
Scope: release truth, model/runtime gating, local-model recommendation truth, Bonsai gating, Mamba/SSM safety, xcodebuild/package-graph hardening, screenshot-driven chat/context reliability fixes, editor release path, stale Hermes/Omega surfaces, and no-sign build integrity.

## Verdict

External ship verdict on April 9, 2026: NOT READY.

The repo is materially safer and more truthful than it was at the start of this audit pass:

- the no-sign Release build now completes successfully
- the direct no-sign Debug build also completes after an explicit package-graph refresh
- targeted release-critical tests pass
- the constrained 18GB recommendation ladder no longer points at quarantined Qwen 3.5 9B
- stale Xcode package-graph state no longer leaves `MLXLMCommon` / `MLXLLM` / `MLXVLM` missing from the active build path
- Bonsai remains truthfully gated out of the installable catalog because Prism's 1-bit runtime support is still absent from the pinned fork
- misleading Mamba agent claims were reduced
- attachment prompting is stronger and more explicit
- unfinished code-editor sidecars are hidden from the default release path

That is not enough for a real ship call. Manual runtime validation across the release surfaces the product owner cares about most is still incomplete.

## What Was Proven

### Build and test reality

- `./scripts/xcodebuild_epistemos.sh -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Release -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
  - Passed on 2026-04-08.
  - This cleared the prior x86_64 `Float16` Release blocker in the Mamba helper path.

- `xcodebuild -project Epistemos.xcodeproj -resolvePackageDependencies`
  - Passed on 2026-04-09.
  - Resolved the local `mlx-swift-lm` package from `LocalPackages/mlx-swift-lm` and cleared the user-reported missing-package-product state for `MLXLMCommon`, `MLXLLM`, and `MLXVLM`.

- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
  - Passed on 2026-04-09.
  - Recompiled successfully after the package refresh; the reported `ChatCoordinator.swift` missing-symbol errors for `sessionFolderPath` / `VaultLifecycleService` did not reproduce.

- `bash -n scripts/xcodebuild_epistemos.sh`
  - Passed on 2026-04-09.
  - Verified the wrapper after adding package preflight plus stale DerivedData test-app cleanup logic.

- `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO -only-testing:EpistemosTests/Mamba2MetalRuntimeTests -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests -only-testing:EpistemosTests/LocalModelInfrastructureTests`
  - Passed on 2026-04-08.
  - Result: 30 tests in 3 suites passed.

- `./scripts/xcodebuild_epistemos.sh -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO -only-testing:EpistemosTests/RuntimeValidationTests`
  - Passed on 2026-04-08.
  - Result: focused runtime-validation slice passed after the screenshot-driven routing/context regressions were patched.

- `./scripts/xcodebuild_epistemos.sh -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO -only-testing:EpistemosTests/NoteChatStateTests -only-testing:EpistemosTests/FileAttachmentBuilderTests`
  - Passed on 2026-04-08.
  - Result: note-chat sanitization and file-attachment contract coverage remained green after the chat/context fixes.

- `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-release-audit-2 test CODE_SIGNING_ALLOWED=NO -only-testing:EpistemosTests/LocalModelInfrastructureTests -only-testing:EpistemosTests/ReleaseScriptAuditTests`
  - Passed on 2026-04-09 when the live LFM/Mamba SSM sentinel files were temporarily masked and restored around the run.
  - Result: 43 tests in 2 suites passed.
  - This confirmed the constrained-fallback fix, Bonsai gating checks, and the wrapper-script audits for package preflight plus stale DerivedData cleanup.

- A broader targeted slice also passed earlier in this audit session:
  - `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO -only-testing:EpistemosTests/AuditFixRegressionTests -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests -only-testing:EpistemosTests/ProductionHardeningTests -only-testing:EpistemosTests/SDPageQueryDescriptorTests -only-testing:EpistemosTests/WorkspaceSnapshotTests -only-testing:EpistemosTests/LocalModelInfrastructureTests -only-testing:EpistemosTests/CloudKnowledgeDistillationTests -only-testing:EpistemosTests/FileAttachmentBuilderTests -only-testing:EpistemosTests/PipelineServiceTests`
  - Result: 85 tests in 8 suites passed.

### Mamba / SSM truth

- Mamba2 helper runtime warmup is real on Apple Silicon.
- `MetalRuntimeManager` compiled all 14 Mamba kernels during the live Mamba smoke.
- Mamba helper runtime respected the safe baseline:
  - chunk size `Q = 128`
  - shared state buffers
  - MPS matmul path intact
- Mamba2 SSM persistence is real on the MLX path.
  - Save and resume passed end to end in live smoke tests.
- The custom Metal helper runtime is still not the live token generation backend.
  - Generation continues through MLX.

### Release-path truth improvements

- Dead local catalog entry `mlx-community/gemma-4-12b-it-4bit` was removed.
- 18GB constrained local fallback now lands on `mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit` instead of quarantined `mlx-community/Qwen3.5-9B-4bit`.
- Bonsai remains absent from `LocalTextModelID` and `LocalModelCatalog`.
  - No Prism 1-bit runtime support exists yet in the pinned `mlx-swift-lm` fork, so there is still no honest end-to-end local Bonsai path.
- Mamba2 no longer advertises release-ready local agent mode.
- Attachment and reference context now explicitly states why context is attached, whether it is required or supplemental, and how text-only models should treat images.
- Standard cloud chats stay on the standard pipeline unless the user explicitly selects agent mode.
- Workspace-summary text is sanitized before it is persisted or reused in prompts.
- Default workspace-awareness injection is lighter when the user already attached explicit context.
- Code-note chat on code files now sees the live code buffer.
- Model Vaults status now reflects configured cloud providers plus installed local models instead of every theoretical target.
- MLX SSM reuse is scoped to the active chat session instead of only the model id.
- Unfinished code editor sidecars are disabled by default in the release path.
- Retired Omega navigation now falls back to supported release tabs instead of restoring hidden state directly.
- Assistant thinking blocks survive Rust-side history compaction again.

## Key Fixes Landed

- `Epistemos/State/InferenceState.swift`
  - Removed dead Gemma 4 12B entry.
  - Tightened Mamba2 agent claims and tool tier.
  - Fixed the constrained recommendation ladder so 18GB Macs no longer resolve to quarantined Qwen 9B for interactive chat fallback.

- `Epistemos/Engine/SSMRuntimeProfile.swift`
  - Added architecture-aware custom SSM runtime support.
  - Removed direct `Float16` size dependency from the profile math.

- `Epistemos/Engine/Mamba2ForwardPass.swift`
  - Kept the real diagnostic path on Apple Silicon.
  - Gated the diagnostic helper path off on non-Apple-Silicon slices so universal Release builds stay honest and compile-safe.

- `Epistemos/Engine/LocalModelInfrastructure.swift`
  - Updated Mamba2 summary text to say Apple Silicon helper warmup explicitly.

- `Epistemos/App/ChatCoordinator.swift`
  - Strengthened attachment/reference prompting contract.
  - Kept standard cloud chat off the Rust agent path unless `.agent` mode is selected.
  - Sanitized workspace summary reuse and reduced default prompt bloat when explicit attachments are present.
  - Cleaned a stale Hermes reference.

- `Epistemos/State/WorkspaceSummaryService.swift`
  - Sanitized generated workspace summaries before persistence and reuse.

- `Epistemos/Views/Notes/CodeEditorView.swift`
  - Disabled AI Partner and semantic sidebar sidecars by default for the release path.
  - Bound code-note chat to the live editor buffer so code files can actually be discussed in-place.

- `Epistemos/Views/Settings/ModelVaultsSettingsView.swift`
- `Epistemos/KnowledgeFusion/CloudKnowledgeDistillationService.swift`
  - Made Model Vaults status and rebuild scope reflect configured cloud providers plus installed local models.

- `Epistemos/Engine/MLXInferenceService.swift`
  - Scoped SSM session reuse to the active chat session id to reduce recurrent-state bleed between separate chats.

- `Epistemos/Views/Notes/OutlineNavigatorView.swift`
  - Replaced `try!` regex initialization with guarded construction.

- `agent_core/src/compaction.rs`
  - Preserved recent assistant thinking blocks during compaction.

- `Epistemos/Models/BrandedTypes.swift`
- `Epistemos/Intents/Custom/NavigationIntents.swift`
- `Epistemos/Intents/Entities/NoteEntity.swift`
- `Epistemos/State/WorkspaceService.swift`
  - Sanitized retired Omega paths out of supported release navigation and workspace restore.

- `Epistemos/Engine/CloudProviderAuthService.swift`
- `Epistemos/Views/Graph/HologramNodeInspector.swift`
  - Removed production force-unwrap hazards.

- `scripts/xcodebuild_epistemos.sh`
- `Makefile`
- `scripts/run_swift_tests.sh`
- `scripts/release/build_release_app.sh`
- `scripts/audit/release_preflight.sh`
- `scripts/audit/verify.sh`
- `TESTING_GUIDE.md`
  - Standardized the xcodebuild wrapper required to avoid the transitive SwiftLint package-plugin failure mode.
  - Added an explicit package-resolution preflight before normal build/test invocations.
  - Added stale DerivedData `Epistemos.app` process cleanup around local model sweeps.

- `EpistemosTests/LocalModelInfrastructureTests.swift`
- `EpistemosTests/LocalRuntimeSmokeSupport.swift`
- `EpistemosTests/ReleaseScriptAuditTests.swift`
  - Added regression coverage for constrained-fallback truth, Bonsai gating, live-validation blocker classification, stale DerivedData cleanup, and package preflight.

## Remaining Ship Blockers

### 1. Full local model release sweep is not complete

The highest-priority product requirement remains incomplete. The app still lacks a verified release matrix for every release-scope local model covering:

- install
- visibility in settings/picker
- output quality
- thinking mode where advertised
- tool behavior where advertised
- file attachments
- note/chat references
- long-context sanity
- vision where advertised

Passing install smoke for a subset of models is not enough.

Fresh evidence in this pass already shows at least one release-scope failure:

- `mlx-community/Falcon-H1-1.5B-Instruct-4bit` failed the live long-context grounding check during `EpistemosTests/LocalModelReleaseSweepTests`.
- The model missed the injected tail sentinel and produced generic boilerplate instead of grounded recall.
- That means the local-model blocker is not just "incomplete coverage"; it already includes a real model-quality failure that must be gated, fixed, or removed from the release path.

Fresh live SSM revalidation on April 9, 2026 also did not fully close:

- With the live LFM/Mamba SSM sentinel files armed, `EpistemosTests/LocalModelInfrastructureTests` hit Hugging Face HTTP `429` rate limits while trying to reinstall `LiquidAI/LFM2.5-350M-MLX-4bit` and `mlx-community/mamba2-2.7b-4bit`.
- That blocked a fresh April 9 live save/resume proof for those two models.
- The non-networked infrastructure slice still passed once those live sentinels were masked and restored, so this was an external validation blocker, not a reproduced local runtime regression.

Additional release-truth hardening landed after the screenshot review:

- welcome-back / session-summary surfaces now strip persisted reasoning artifacts even if older summaries were already stored on disk
- main chat treats explicit file/note/chat context as required and suppresses optional workspace-background injection in that case
- note chat now treats the current live note buffer as the primary document on all submit paths
- the code editor release path now exposes only the focused ask-bar mode
- release-facing local-model pickers and Model Vault targets now hide locally installed models that already failed the April 8 live validation sweep

### 2. Cloud validation is incomplete

OpenAI is the only cloud provider with real access per the current ground truth, but the requested end-to-end validation sweep across fast / thinking / pro / agent / attachments / note refs / chat refs / permission flow was not completed in this pass.

### 3. Manual graph feel validation is still missing

Static code inspection and prior throttling work are not a substitute for a real zoom/pan/drag feel pass. The user explicitly reports stutter, and that report has not been closed with fresh manual runtime evidence in this pass.

### 4. Mamba phase is only phase-1 complete

The truthful status after this audit pass is:

- helper kernels compile and warm on Apple Silicon
- SSM save/resume works on the MLX path
- diagnostic helper pass is validated
- generation still runs through MLX

That is real progress, but it is not a completed custom Metal Mamba backend.

### 5. Manual release operations were not executed

The following were not performed in this pass:

- signing
- notarization
- packaging
- release artifact smoke pass

### 6. Known warning debt remains

- The local MLX fork still emits Swift 6 sendability warnings in `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/ChatSession.swift`.
- Mamba2 live smoke still logs:
  - `No chat template was included or provided...`
- The April 9 Mamba-only `LocalModelReleaseSweepTests` orphaned DerivedData `Epistemos` test-app processes did lead to a concrete wrapper hardening patch.
  - The wrapper now cleans stale DerivedData `Epistemos.app` processes before and after local sweep runs.
  - A fully clean fresh Mamba-only rerun still needs to be re-proven after that hardening.
- The successful Release build still emitted third-party CodeEdit/TreeSitter warning noise referencing `/Users/Khan/Developer/CodeEditLanguages/...`.

These did not block the no-sign Release build on 2026-04-08, but they are still release debt.

## Feature Classification After This Pass

### Shippable or close enough to keep visible

- MLX local generation path
- SSM persistence on supported local SSM models
- strengthened attachment/reference prompt contract
- calmer default code editor path

### Infrastructure present but not fully end to end

- Mamba custom Metal helper runtime
- custom Mamba diagnostic forward pass
- broader release-scope local model matrix
- full OpenAI validation matrix

### Hidden or truthfully downgraded

- Mamba2 local agent mode
- default code editor AI Partner / semantic sidebar sidecars
- retired Omega release navigation state

### Additional screenshot-driven hardening completed on April 9, 2026

- Shared output sanitization now strips orphan `</think>` / `</thinking>` tags and drops the leaked reasoning prelude before the visible answer.
- That closes the screenshot-reproduced failure mode where welcome-back summaries and chat transcripts could show internal planning text even after the earlier summary/context fixes.

## Required Next Gate Before Any Ship Call

1. Complete the full local-model release sweep with runtime evidence.
2. Complete the OpenAI validation sweep with real credentials and captured results.
3. Perform a manual graph feel pass and fix any remaining stutter regressions.
4. Decide whether to add a real Mamba chat template or explicitly downgrade expectations in UI/docs.
5. Run signing, notarization, packaging, and artifact smoke once the above are green.

Until those are done, the build is cleaner and more truthful, but the product is not honestly release-ready.
