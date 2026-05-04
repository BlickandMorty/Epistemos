# Full Floor Source Guard And Model Vault Provider Deliberation - 2026-04-30

## Scope

Repair the non-FTS failures from `/tmp/epistemos-full-test-after-cargo-mirror-20260430.log` without touching protected editor, graph-renderer, or Rust internals.

## Repo Evidence

- Full Swift floor completed instead of wedging, but exited 65 with 24 issues after 5,021 tests in 563 suites.
- Non-FTS failures are stale source guards in `HarnessSubsystemTests`, `NonAgentPruningValidationTests`, `RuntimeValidationTests`, and `ThemePairTests`, plus one real provider drift in `AppBootstrap`.
- `BootstrapPacketBuilder.render(_:)` now appends stable `<operating_principles>` cache padding after `</environment_context>`, so the rendered packet should no longer end with the environment close tag.
- `SetupAssistantView` still exposes unconditional `Button("Skip")` from the vault step to `.model`; the test was matching the old animation symbol exactly.
- `SettingsView.SettingsSection.visibleSections` now gates Pro-only sidebar sections with `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`, matching the MAS sandbox hardening tests.
- `NodeInspectorState` and `PinnedInspector` now share a `logPrefix` helper; the literal source contains `"\(logPrefix): failed to fetch page summary"` while call sites pass `NodeInspectorState` and `PinnedInspector`.
- `LiquidGreeting` now includes `searchMode` in `taskKey` and keeps a cheap cursor blink for search mode. The old tests were checking the pre-search task id and treating any `cursorVisible` as the removed liquid canvas timeline.
- `AppBootstrap.cloudKnowledgeDistillationService` currently computes `let initialTargets = inferenceState.modelVaultTargets()` and passes `targetsProvider: { initialTargets }`, despite the surrounding comment saying first access should read current targets. This can make model vault rebuilds stale after provider/model visibility changes.

## Research Evidence

- The April 30 fusion authority prioritizes build/test floor first and requires deliberation before implementation.
- The release-audit workflow requires log-first evidence and no release-ready claim until repeated zero-fail validation.
- No web evidence is needed; this is local test/build behavior and current source alignment.

## Alternatives Considered

- Defer all source-guard repairs: rejected because the full floor cannot distinguish real blockers while stale guards remain red.
- Patch only tests: rejected because the model-vault provider snapshot is a real behavior drift caught by the source guard.
- Broaden to SQLite/FTS failures: rejected for this slice; that cluster needs a separate schema/SQLite capability decision.

## Files Likely Touched

- `Epistemos/KnowledgeFusion/CloudKnowledgeDistillationService.swift`
- `Epistemos/App/AppBootstrap.swift`
- `EpistemosTests/HarnessSubsystemTests.swift`
- `EpistemosTests/NonAgentPruningValidationTests.swift`
- `EpistemosTests/RuntimeValidationTests.swift`
- `EpistemosTests/ThemePairTests.swift`

## Forbidden Files

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/`
- DerivedData and `.xcresult` bundles

## Tests And Logs

- Focused verification: affected Swift Testing suites only, log to `/tmp/epistemos-source-guard-focused-20260430.log`.
- If focused verification passes, rerun full Swift floor and update `BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`.
- Protected-path diff audit after edits.

## Rollback

- Revert only the files listed above.
- If the model-vault provider actor isolation change does not compile cleanly, roll it back and split into a separate async-provider repair.

## Stop Triggers

- Any protected-path diff appears.
- Any production edit outside the model-vault provider path becomes necessary.
- Focused tests reveal a new behavior failure outside this slice.

## Result

Status: **passed focused verification without additional source edits**.

Current source already contains the intended model-vault provider capture fix:

- `AppBootstrap.cloudKnowledgeDistillationService` captures `let inferenceState = self.inferenceState`.
- The `targetsProvider` closure then calls `inferenceState.modelVaultTargets()`, so rebuilds read current model-vault visibility instead of a stale launch snapshot.
- The source guards in `HarnessSubsystemTests`, `NonAgentPruningValidationTests`, `RuntimeValidationTests`, and `ThemePairTests` now match current source.

Verification:

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
