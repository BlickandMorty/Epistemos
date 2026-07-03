# Note / Goose / MarkEdit Audit Progress - 2026-07-02

## Scope

Owner request covered:
- Notes should be real Markdown files and open immediately.
- One "New Note" entry point should ask for Prose or Document.
- Existing notes should always be switchable across Prose, Document, Preview, and Source.
- Source / MarkEdit must show Markdown content, keep the surface switcher visible, keep settings in the native toolbar, and avoid the extra file/title rows.
- Code files must stay code files when renamed.
- Goose and note freezes must be measured before further fixes.
- Run a thermonuclear code-quality review posture, not blind edits.

## 2026-07-02 07:10 Checkpoint

Additional fixed / verified items:
- MarkEdit / Source and code editor theme propagation now share real theme tokens for preset and custom themes. Ember and Platinum no longer stay on the wrong teal/source palette path.
- Source / MarkEdit no longer depends on the old in-content file row for settings or surface switching; the native toolbar path carries the mode buttons and settings.
- Code editor rename and creation now preserve the actual code-file identity, and the code editor title bar resolves a file-kind icon through path / UTType / extension fallback.
- MarkEdit and code editor invisibles are reset off by default so the weird dots and small return markers are not forced into the editor.
- Source outline routing is surface-aware: Source uses the source editor content, Prose uses the prose outline, and Document has its own projection outline path.
- Preview mode keeps the same top chrome backdrop as the other note surfaces without adding the extra fake top padding that pushed the content down.
- Graph page routes no longer mount the embedded graph HTML Workspace dock. The bottom "HTML Workspace" quick action was also removed from regular note / graph-page note surfaces.
- Graph chrome is now canvas-only: sidebar, inspector eject controls, mini inspector windows, pinned inspector views, FPS HUD, and Metal resume all hide / pause when the graph route is a page or embedded editor.
- Graph inspector preview body uses the Anthropic Sans app font while keeping node titles in the pixel display font.
- Goose Web-only source guard was refreshed for the current escaped staging-script CSS patterns.

Passed after these fixes:

```sh
xcodebuild -quiet test -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/GooseWebOnlySurfaceSourceTests
```

Passed before the final preview-padding correction:

```sh
xcodebuild -quiet test -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/RuntimeValidationTests/graphOnlyChromeHidesSidebarAndPausesMetalOnWorkspaceRoutes \
  -only-testing:EpistemosTests/GraphWorkspaceRouteTests \
  -only-testing:EpistemosTests/EpdocCopilotSurfaceTests \
  -only-testing:EpistemosTests/HTMLWorkspaceSourceGuardTests/newVisualCreationRoutesToHTMLWorkspaceNotMermaid \
  -only-testing:EpistemosTests/CodeEditorPolishTests \
  -only-testing:EpistemosTests/MarkEditChromeModeSplitTests \
  -only-testing:EpistemosTests/NoteEditorLayoutTests \
  -only-testing:EpistemosTests/SSGCCodeEditorChromeThemeTests \
  -only-testing:EpistemosTests/SSTHXHtmlWorkspaceThemeTests \
  -only-testing:EpistemosTests/GraphInspectorSourceGuardTests
```

Passed again after removing the preview-only top padding:

```sh
xcodebuild -quiet test -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/NoteEditorLayoutTests \
  -only-testing:EpistemosTests/RuntimeValidationTests/graphOnlyChromeHidesSidebarAndPausesMetalOnWorkspaceRoutes \
  -only-testing:EpistemosTests/GraphWorkspaceRouteTests \
  -only-testing:EpistemosTests/EpdocCopilotSurfaceTests \
  -only-testing:EpistemosTests/HTMLWorkspaceSourceGuardTests/newVisualCreationRoutesToHTMLWorkspaceNotMermaid \
  -only-testing:EpistemosTests/CodeEditorPolishTests \
  -only-testing:EpistemosTests/MarkEditChromeModeSplitTests \
  -only-testing:EpistemosTests/SSGCCodeEditorChromeThemeTests \
  -only-testing:EpistemosTests/SSTHXHtmlWorkspaceThemeTests \
  -only-testing:EpistemosTests/GraphInspectorSourceGuardTests
```

## 2026-07-02 07:35 Thermonuclear Cleanup Checkpoint

Maintainability fixes after the UI bug batch:
- Extracted the live preview/book layout, preview chrome inset reader, and preview layout metrics from `NoteDetailWorkspaceView.swift` into `NotePreviewSurfaceView.swift`.
- Deleted the dead `NotePreviewView2` TextKit preview bridge. Current preview rendering goes through `AdaptiveNotePreviewView2` and `MarkdownTextView`; no call sites used the old bridge.
- Deleted the stale `NotePreviewDisplay.renderedMarkdown` identity wrapper and passed Markdown directly into the preview surface.
- Retargeted preview source guards so `NoteDetailWorkspaceView.swift` owns the workspace call site while `NotePreviewSurfaceView.swift` owns preview chrome/layout behavior.
- Updated the stale utility-panel test to require Notes / Omega / Settings and the status-bar subset without rejecting current Browser, browser-use Pro, and Meeting Note utility panels.
- Reduced `NoteDetailWorkspaceView.swift` from about 4.5k lines to 3,972 lines; `NotePreviewSurfaceView.swift` is 457 focused lines.

Passed:

```sh
xcodebuild -quiet test -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/NoteEditorLayoutTests \
  -only-testing:EpistemosTests/NoteWindowManagerTests
```

Passed broader focused bucket after extraction:

```sh
xcodebuild -quiet test -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/NoteEditorLayoutTests \
  -only-testing:EpistemosTests/NoteWindowManagerTests \
  -only-testing:EpistemosTests/RuntimeValidationTests/graphOnlyChromeHidesSidebarAndPausesMetalOnWorkspaceRoutes \
  -only-testing:EpistemosTests/GraphWorkspaceRouteTests \
  -only-testing:EpistemosTests/EpdocCopilotSurfaceTests \
  -only-testing:EpistemosTests/HTMLWorkspaceSourceGuardTests/newVisualCreationRoutesToHTMLWorkspaceNotMermaid \
  -only-testing:EpistemosTests/CodeEditorPolishTests \
  -only-testing:EpistemosTests/MarkEditChromeModeSplitTests \
  -only-testing:EpistemosTests/SSGCCodeEditorChromeThemeTests \
  -only-testing:EpistemosTests/SSTHXHtmlWorkspaceThemeTests \
  -only-testing:EpistemosTests/GraphInspectorSourceGuardTests
```

Passed scoped whitespace check:

```sh
git diff --check -- Epistemos/Views/Notes/NoteDetailWorkspaceView.swift \
  Epistemos/Views/Notes/NotePreviewSurfaceView.swift \
  EpistemosTests/NoteEditorLayoutTests.swift \
  EpistemosTests/NoteWindowManagerTests.swift \
  docs/handoffs/NOTE_GOOSE_MARKEDIT_AUDIT_PROGRESS_2026_07_02.md
```

## 2026-07-02 08:15 Broad-Suite Parser Checkpoint

Measured broad-suite blocker:
- Full suite attempt:

```sh
xcodebuild -quiet test -scheme Epistemos -destination 'platform=macOS' \
  -resultBundlePath /tmp/epi_broad_full_20260702_0745.xcresult
```

- Interrupted after 473s because it was stuck long enough to measure first.
- Result bundle did not finalize cleanly after interruption.
- Sample saved at `/tmp/epi_fullsuite_app_sample_20260702_0752.txt`.
- The sample was inside `GeneratedReliabilityMatrixTests.benchmarkParserThroughputEnvelope`, with the hot stack dominated by `QueryParser.parseToAST` -> `heuristicParseToAST` -> `extractPathQuery` -> Swift Regex parser/initialization.

Patch:
- Hoisted the three natural-language path regexes in `QueryParser.extractPathQuery` to private static regex properties.
- Added `QueryParserVisibilityTests.naturalPathQueryRegexesAreHoistedOutOfHotParserPath` so the regex literals do not drift back into the hot parser function.

Red / green evidence:

```sh
xcodebuild -quiet test -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/QueryParserVisibilityTests \
  -resultBundlePath /tmp/epi_query_visibility_red_20260702.xcresult

xcodebuild -quiet test -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/QueryParserVisibilityTests \
  -resultBundlePath /tmp/epi_query_visibility_green_20260702.xcresult

xcodebuild -quiet test-without-building -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/GeneratedReliabilityMatrixTests \
  -resultBundlePath /tmp/epi_reliability_matrix_after_regex_20260702.xcresult
```

Results:
- Query parser visibility guard passed: 7 tests, 0 failures.
- Generated reliability matrix passed: 6 parameterized tests, 1,200 runs, 0 failures, about 40s runtime.
- Method-level `-only-testing:.../benchmarkParserThroughputEnvelope` did not select any Swift Testing case, so use the suite-level filter above for this proof.

## Fixed / Verified This Pass

### Code file rename stays code

Changed `VaultIndexActor.renamePageFile` so a tracked file keeps its existing extension when renamed. If a user types another importable extension into the title, the old code extension still wins. For example, `Original.swift` renamed to `Renamed.html` becomes `Renamed.swift`, not `Renamed.md` or `Renamed.html.swift`.

Also migrated `CodeArtifactSidecar` from the old vault-relative code path to the renamed path.

Covered by:
- `VaultIndexActorTests.renamePageFilePreservesCodeFileExtension`
- `VaultIndexActorTests.renamePageFileMigratesCodeSidecarAndKeepsOriginalExtension`
- `VaultIndexActorTests.renamePageFileReportsNilWhenTrackedFileIsMissing`
- `CodeEditorPolishTests.codeFileRenamePreservesExistingFileExtension`

### Sidebar opens code files in Source

Changed the Notes sidebar so code-backed pages open in `.source`, and code creation opens the source editor immediately instead of falling into Prose.

### Goose transition stall measured and patched

Live sample before fix:
- `/tmp/epi_goose_transition_sample_20260702.txt`
- Main thread was dominated by `LandingView.openEpistemosGoose()` -> `GooseSurfaceAvailability.current()` -> `GooseWebUIResolver.indexURL()` -> eager candidate collection -> `Sequence.contains(where:)` -> repeated URL path standardization.

Patch:
- `GooseWebUIResolver.indexURL` now streams candidates and short-circuits on the first valid ACP-mode artifact.
- Replaced O(n^2) URL de-dupe with `UniqueURLAccumulator` and a `Set`.
- Kept diagnostic candidate materialization available for summaries.

Live sample after fix:
- `/tmp/epi_goose_transition_after_resolver_20260702.txt`
- The old resolver stack no longer appeared. Main thread was mostly parked in the run loop with small WebKit layer commits during reveal.

Covered by:
- `GooseWebUIResolverTests.resolverShortCircuitsActivationCandidatesWithoutQuadraticPathScans`
- `GooseWebUIResolverTests.resolverKeepsActivationPathChecksLexical`
- focused resolver tests passed.

### Note create/open checked in fresh app

Fresh DerivedData app:
- `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Debug/Epistemos.app`

Observed:
- Landing `New Note` shows the Prose / Document / Cancel chooser.
- Choosing Prose opens a blank Markdown-backed note immediately.
- Existing Markdown note `PLAN_3_CAPABILITIES_2026_06_28` opened and rendered in Prose.
- Switching to Source showed Markdown content in MarkEdit instead of a blank source surface.
- Source toolbar had individual native buttons: Edit/Prose, Document, Preview, Source, More, MarkEdit settings.
- No extra MarkEdit file row was visible.

Samples:
- `/tmp/epi_note_create_fresh_20260702.txt`
- `/tmp/epi_note_open_fresh_20260702.txt`

Notes:
- The create sample is mostly `NSAlert.runModal`, because the chooser intentionally waits for user choice.
- The note-open sample was partly polluted by Computer Use accessibility inspection, so treat it as a manual no-freeze check rather than a clean perf proof.

## Tests Run

Passed:

```sh
xcodebuild -quiet test -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GooseWebUIResolverTests
```

Passed:

```sh
xcodebuild -quiet test-without-building -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/GooseAppContextSnapshotTests \
  -only-testing:EpistemosTests/GooseRuntimeSupervisorTests \
  -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests \
  -only-testing:EpistemosTests/MarkEditChromeModeSplitTests \
  -only-testing:EpistemosTests/NoteEditorLayoutTests \
  -only-testing:EpistemosTests/LandingOptimizationTests/prewarmedGooseSurfaceAvoidsZeroOpacityColdReveal \
  -only-testing:EpistemosTests/CodeEditorPolishTests/codeFileRenamePreservesExistingFileExtension \
  -only-testing:EpistemosTests/VaultIndexActorTests/renamePageFilePreservesCodeFileExtension \
  -only-testing:EpistemosTests/VaultIndexActorTests/renamePageFileMigratesCodeSidecarAndKeepsOriginalExtension \
  -only-testing:EpistemosTests/VaultIndexActorTests/renamePageFileReportsNilWhenTrackedFileIsMissing \
  -only-testing:EpistemosTests/LandingFeatureButtonsPlan3Tests
```

Passed:

```sh
git diff --check
```

Passed:

```sh
xcodebuild -quiet test -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/AgentAuthorityPersistenceTests \
  -only-testing:EpistemosTests/AgentModeUnavailableCopyTests \
  -only-testing:EpistemosTests/AppStoreHardeningTests/appStoreSourceCannotCanImportGGUFRuntimeFromSharedDerivedData \
  -only-testing:EpistemosTests/AuditFixRegressionTests/modelProfileCreationSheetAvoidsRetiredHermesLabels \
  -only-testing:EpistemosTests/EmlRouteFusionHealthRowTests \
  -only-testing:EpistemosTests/GooseWebOnlySurfaceSourceTests/nativeAgentWindowKeepsGoosePrimary \
  -only-testing:EpistemosTests/GooseWebOnlySurfaceSourceTests/landingExposesGooseWebOnlyEntry
```

This cleared the first stale SourceMirror/source-guard bucket:
- `AuthoritySettingsView.swift` retired from simplified Settings; authority durability now pins `AppBootstrap`'s explicit file-backed store and absence of the retired UI.
- `AgentModeUnavailableView.swift` retired; capability honesty now pins `LocalTextModelID.agentToolTier` (`Qwen 3 4B` full-agent, `Qwen 3.5 4B` not full-agent).
- `LocalGGUFClient.swift` retired; App Store hardening now asserts no Swift source can-imports `GGUFRuntimeBridge`.
- `ModelProfileCreationSheet.swift` retired; label guard now checks active `InferenceState` display names.
- `EmlRouteFusionHealthRow.swift` / `GooseSurfaceWindowController.swift` retired; tests now assert the current simplified/inline Goose and EML shapes.

Passed:

```sh
xcodebuild -quiet test -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/ArxivPlan3Tests
```

This cleared the arXiv Plan 3 bucket:
- `ArxivNoteDraft` now normalizes each author/category before joining, so embedded controls or trailing whitespace do not create labels like `cs.AI , cs.CL`.
- ArXiv ingest fixtures now use valid fake PDF magic (`%PDF-`) instead of tripping the intentionally hardened shared `Plan3ImportFileIO.copyFileContents` validation.
- Stale arXiv docs/source guards were updated for current line wrapping and the `runDetachedCancellable` priority parameter shape.

Passed:

```sh
xcodebuild -quiet test -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/BrowserUseCodepackPlan3Tests

xcodebuild -quiet test-without-building -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/BrowserUseAdapterPlan3Tests \
  -only-testing:EpistemosTests/BrowserUseCodepackPlan3Tests \
  -only-testing:EpistemosTests/BrowserUseRuntimeSupervisorTests
```

This cleared the Browser-use Plan 3 bucket:
- Vendor manifest paths now use safe relative directory names (`wheels`, `playwright`) and the adapter manifest records all three Epistemos shim files.
- Browser-use tests were aligned with the current stricter symlink/owner/CDP diagnostics and current signed-bundle evidence fields.
- Browser-use canon docs now explicitly record the landed vendor/runtime staging lane, compatibility shims, source-guard evidence, and package-result checkpoint evidence.
- The codepack guard now expects whitespace-normalized strings for its signed-bundle fixture sentences instead of impossible `\n` substrings after doc normalization.

Passed:

```sh
xcodebuild -quiet test -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/CompanionOutputSchemaValidationTests
```

This cleared the Companion output-schema behavior bug:
- `CompanionOutputSchemaValidation` now rejects trailing commas before `}`/`]` outside strings before handing the object to Foundation.
- This is needed because the macOS 26 Foundation JSON parser accepts `{"type":"object",}` as valid, but the Companion contract field must stay strict enough to reject broken JSON Schema text.

Passed:

```sh
xcodebuild -quiet test -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/AnswerPacketStoreTests \
  -only-testing:EpistemosTests/AnswerPacketEmitterTests
```

This cleared the AnswerPacket persistence-isolation bucket:
- `AnswerPacketEmitter.shared` still uses the default app-support `AnswerPacketStore`.
- `AnswerPacketEmitter.makeForTesting()` now constructs a fresh emitter with persistence disabled instead of lazily resolving the production store. This prevents tests from accidentally restoring the user's real `answer_packets.jsonl` when they expect no store to be configured.
- The first focused exact test passed before the patch only because the local default store happened to have no restorable packets in that isolated run; the broad-suite red was still valid because the source allowed global persistence leakage.

Passed:

```sh
xcodebuild -quiet test -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/ContextualShadowsStateTests
```

This cleared the Contextual Shadows panel-visibility bucket:
- The production code already followed the 2026-06-20 SS-IR rule: a recall query lights/publishes payload but does not auto-open the overlay while typing.
- Older ContextualShadows V0 tests still expected `isPanelVisible == true` after result/error/fallback publication. They now assert payload publication, closed panel state, and explicit `openPanel()` as the sole opener.
- This preserves the user's "no weird pixel box overlaying things" requirement and matches the dedicated `SSIRNoAutoShowTests` contract.

Passed:

```sh
xcodebuild -quiet test -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/CoworkChatModeTests \
  -only-testing:EpistemosTests/LocalForAllModesAgentRouteGuardTests \
  -only-testing:EpistemosTests/RuntimeValidationTests/thinkingOperatingModeStaysOffForUnverifiedThinkingLocalModels \
  -only-testing:EpistemosTests/RuntimeValidationTests/availableOperatingModesMatchTheActiveSelection
```

This cleared the Cowork/Act local-routing bucket:
- The production routing still intentionally follows the 2026-06-26 native local chat/agent prune: local MLX/Qwen chat selections normalize away, `effectiveLocalAgentTextModelID` is nil, and Act requires a configured cloud agent-capable route.
- Tests no longer claim "zero cloud" local Act support. They now verify the current cloud-backed Act availability copy, route normalization, and source-guard shape for `.agent` in `InferenceState.effectiveChatSurfaceSelection`.
- The focused suite is green after the source-guard was tightened to inspect only the routing switch, not unrelated `.pro, .agent` reasoning-tier code.

Passed:

```sh
xcodebuild -quiet test-without-building -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/GooseACPClientTests/providerCatalogDecodersBoundLiveACPPayloads
```

Passed:

```sh
xcodebuild -quiet test-without-building -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/GooseWebUIStagingTests/stagingScriptForcesRelativeRendererAssets \
  -only-testing:EpistemosTests/GooseWebUIStagingTests/stagingGraftsWireLiveParityFeatures \
  -only-testing:EpistemosTests/GooseWebViewBootShimTests/masBootstrapDisablesRuntimeExtensibilityAffordances \
  -only-testing:EpistemosTests/GooseWebViewBootShimTests/gooseSurfaceShowsStartupPlaceholderAndRetriesRuntime \
  -only-testing:EpistemosTests/GooseWebViewBootShimTests/gooseSurfaceCoordinatorDoesNotOwnNativePromptPanels \
  -only-testing:EpistemosTests/GooseWebViewBootShimTests/bootstrapRoutesNativeAffordances \
  -only-testing:EpistemosTests/GooseWebNativeAffordanceBridgeTests/settingsAffordancesPersistThroughNativeHost
```

This cleared the currently reproducible Goose unit/source-guard bucket:
- The exact provider catalog decoder test is green on current build products; the earlier broad-suite `.dataCorrupted` entry did not reproduce after the focused repairs/build refresh.
- The staging script guards prove the ACP provider graft still carries live config-status overlay, uncapped provider templates, model capability inventory, session model/provider writes, native local ACP config persistence, and the validate-only/typecheck gates.
- The boot-shim/native-affordance guards prove MAS runtime-extensibility suppression, startup placeholder retry wiring, native prompt-panel ownership separation, native affordance routing, and host-side setting persistence.

Before probing live Goose tests, stale manual-check processes were stopped:
- `/Users/jojo/.../Build/Products/Debug/Epistemos.app`
- `/Users/jojo/Library/Application Support/Epistemos/GooseRuntime/goose serve --host 127.0.0.1 --port 3284 --with-builtin developer`

Passed after cleanup:

```sh
xcodebuild -quiet test-without-building -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/GooseLiveIntegrationTests/liveGooseServeAcceptsSwiftACPInitialize

xcodebuild -quiet test-without-building -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/GooseLiveIntegrationTests/liveGooseServeCompletesPromptEndTurn

xcodebuild -quiet test-without-building -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/GooseProviderCatalogLiveIntegrationTests/liveProviderModelCatalogComesFromGooseACP

xcodebuild -quiet test-without-building -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/GooseSessionLifecycleLiveIntegrationTests/liveGooseServeListsLoadsAndForksSessionsThroughACP

xcodebuild -quiet test-without-building -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/GooseLiveIntegrationTests/liveGooseWebViewBootsStagedUIThroughNarrowShim \
  -only-testing:EpistemosTests/GooseLiveIntegrationTests/liveGooseWebViewDrivesNativeHostAffordances \
  -only-testing:EpistemosTests/GooseWebPromptLiveIntegrationTests/liveGooseWebViewSubmitsPromptThroughRendererToEndTurn \
  -only-testing:EpistemosTests/GooseWebRouteLiveIntegrationTests/liveGooseWebViewRendersPhase0Routes

xcodebuild -quiet test-without-building -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/GooseCustomCapabilityLiveIntegrationTests/liveGooseServeHandlesRecipesSchedulesAndExtensionsThroughDynamicCustomACP \
  -only-testing:EpistemosTests/GooseProviderMutationLiveIntegrationTests \
  -only-testing:EpistemosTests/GooseSettingsMutationLiveIntegrationTests \
  -only-testing:EpistemosTests/GooseSourceMutationLiveIntegrationTests \
  -only-testing:EpistemosTests/GooseCustomACPReadOnlyLiveProof \
  -only-testing:EpistemosTests/GooseDynamicCustomACPClientTests
```

This cleared the focused Goose live-runtime bucket:
- Live ACP initialize, `session/new`, prompt end-turn, provider catalog, session list/load/fork, WebView boot, native affordances, WebView prompt routing, route rendering, custom capability, provider/settings/source mutations, and dynamic custom ACP paths are green on current build products.
- The earlier broad-suite Goose live timeouts are now best classified as stale runtime/process pollution or stale build-product noise. They did not reproduce after killing the old Debug app and `goose serve`.
- Keep the process-cleanup step before future broad live runs; otherwise the tests can target or contend with an old runtime.

Inconclusive / red:

```sh
xcodebuild -quiet test-without-building -scheme Epistemos -destination 'platform=macOS'
```

That broad run was interrupted after Xcode got stuck finalizing logs / test session:
- `waiting for workers to materialize`
- `Waiting for -runningDidFinish call`
- `TEST EXECUTE INTERRUPTED`

The partial result bundle recorded 76 unique failure summaries. A compact list was saved to:
- `/tmp/epistemos_full_xcresult_failures_20260702.tsv`

Main red buckets:
- SourceMirror missing-file guards: the first bucket above has been patched and focused-green; any remaining missing-file red should be treated as a separate stale guard or real retired-surface mismatch.
- Plan 3 docs/source guards out of sync with current docs and renamed research files.
- Browser-use Pro gate/runtime tests expecting a signed/staged payload while current local payload reports incomplete/unsafe paths.
- arXiv Plan 3 suite: fixed and focused-green.
- Goose live integration timeouts for ACP session/new, WebView boot, provider catalog, and session lifecycle: focused-green after stale process cleanup.
- One Goose native affordance bridge test crash: focused-green after stale process cleanup.
- Goose unit/source-guard drift: exact decoder, staging, boot-shim, and native-affordance guards are focused-green on current build products.
- Contextual shadows panel visibility expectations: fixed and focused-green.
- Companion output schema accepts malformed JSON: fixed and focused-green.
- Cowork Act local-routing stale expectation: fixed and focused-green.
- A few model/profile/source-guard tests pointing at removed or renamed files.

## Remaining Work Queue

1. Re-run the broad suite with a clean result path and without stale app processes; if Xcode finalization hangs again, split live integration tests from source-guard/unit tests.
2. Triage SourceMirror failures first. They make many audit tests noisy and hide real failures.
3. Treat Goose transition and focused Goose live-runtime evidence as green, but keep stale-process cleanup before any broad live run.
4. Triage Browser-use Pro gate failures as a packaging/state problem, not as a MAS surface problem.
5. Manually re-check Preview chrome in the app after the preview-padding correction; automated guards now cover the removed spacer, but a screenshot pass should verify the toolbar/titlebar backdrop looks right.
6. Re-sample note open with a lower-AX method if the user reproduces a real freeze again; the fresh app did not reproduce it in this pass.

## Important Local State

The worktree is broadly dirty with unrelated/user/generated changes. Do not revert unrelated files.

Correct app used for manual checks:
- `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Debug/Epistemos.app`

Avoid stale app:
- `/Users/jojo/.epistemos-isoloop-dd/Build/Products/Debug/Epistemos.app`
