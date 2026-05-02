# Contextual Shadows Source Mirror Deliberation - 2026-04-30

## Repo Evidence

- Full Swift floor attempt `/tmp/epistemos-release-split-full-xcode-test-20260430.log` reached live Swift Testing and then blocked at `Contextual Shadows V0 is the production-mounted recall surface`.
- Hang sample `/tmp/epistemos-full-test-hang-sample-33021.txt` shows the main thread inside `ContextualShadowsStateTests.contextualShadowsProductionMountsArePresent()` while `String(contentsOf:)` was blocked in kernel `open()`.
- `EpistemosTests/ContextualShadowsStateTests.swift` currently reads repo source through a local `repoText(_:)` helper derived from `#filePath`, which points at `/Users/jojo/Downloads/Epistemos`.
- Existing source-mirror repairs already established the pattern: source-guard tests should read from `SourceMirrorTestSupport` instead of the live checkout to avoid macOS protected-folder runtime prompts under the Xcode test host.
- The current test bundle source mirror already contains all files needed by this suite:
  - `Epistemos/App/AppBootstrap.swift`
  - `Epistemos/App/AppEnvironment.swift`
  - `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
  - `Epistemos/Views/Chat/ChatInputBar.swift`
  - `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`
  - `Epistemos/State/ContextualShadowsState.swift`

## Classification

Core test-harness repair. No production behavior change.

## Decision

Approved for a narrow test-only fix:

- Remove the direct repo-root `#filePath` helper from `ContextualShadowsStateTests`.
- Add a local helper that delegates to `loadMirroredSourceTextFile(_:)`.
- Preserve all existing Contextual Shadows V0 assertions.
- Do not edit production Contextual Shadows, Halo, note editor, graph, project, entitlement, or plist files.

## Alternatives Considered

- Grant macOS folder access to the test host: rejected because it is an environmental/manual permission workaround and does not make CI/repeatable shell verification better.
- Skip the source-guard test in full floor: rejected because it hides a real production-mount guard.
- Move the repo outside `Downloads`: rejected because it is environment management, not a branch fix.

## Files Likely Touched

- `EpistemosTests/ContextualShadowsStateTests.swift`
- `docs/fusion/deliberation/contextual_shadows_source_mirror_deliberation_2026_04_30.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

## Forbidden Files

- `Epistemos/State/ContextualShadowsState.swift`
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `Epistemos.xcodeproj/project.pbxproj`
- release entitlements/plists
- `graph-engine/`

## Tests And Logs

- Focused red evidence already exists:
  `/tmp/epistemos-release-split-full-xcode-test-20260430.log`
- Post-fix focused verification:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ContextualShadowsStateTests test`
- Log focused verification to:
  `/tmp/epistemos-contextual-shadows-source-mirror-20260430.log`
- Then run protected-path and whitespace guardrails.

## Execution Result

Accepted as part of the V0 backend/source-guard evidence slice.

Fresh verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ContextualShadowsStateTests test | tee /tmp/epistemos-contextual-shadows-v0-backend-source-mirror-20260501.log
```

Result:

- Swift Testing: 17 tests in 1 suite passed.
- Suite: `ContextualShadowsState`.
- Source mirror guard now reads through `loadMirroredSourceTextFile(_:)`.
- Xcode result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_22-58-00--0500.xcresult`.
- Xcode printed the inherited SwiftLint plugin failures for `CodeEditTextView` and `CodeEditSourceEditor` after `** TEST SUCCEEDED **`; this is existing package-plugin debt, not caused by this slice.

## Manual Verification

Not required for this test-harness repair. Runtime Contextual Shadows UI verification remains deferred by user request.

## Rollback

- Revert only `EpistemosTests/ContextualShadowsStateTests.swift` and this deliberation/floor-log append.

## Stop Triggers

- Source mirror is missing required files after rebuild.
- Focused test reveals a real Contextual Shadows assertion failure after the direct-read hang is removed.
- Any protected-path diff appears.
