# Halo V0 Shadow Backend Route PR1 Deliberation - 2026-05-01

## Gate

Approved action: **route the existing production Contextual Shadows V0 panel
through the newer Shadow backend when that backend is ready**.

This gate does not approve full V1 Halo editor mounting, trailing-edge glyph
work inside `ProseEditor*`, inline editing inside the Halo panel, graph-engine
work, renderer work, or raw merges from older Halo worktrees.

## Decision

Choose the middle route from the current-state doc:

- Keep the production-mounted V0 `ContextualShadowsButton` and
  `ContextualShadowsPanel`.
- Do not mount the full V1 `HaloController` into the editor yet, because the
  canonical V1 anchor requires protected `ProseEditor*` work.
- Prefer `ShadowSearchServicing` for V0 recall when AppBootstrap has opened the
  per-vault Shadow backend.
- Fall back to `InstantRecallService` when the Shadow backend is not configured.

This gives the user-visible recall loop a real path to the new Shadow index
without touching editor hot paths.

## Repo Evidence

- `ContextualShadowsState` is already production-mounted through
  `AppEnvironment`.
- `NoteDetailWorkspaceView`, `ChatInputBar`, and `ProseEditorRepresentable2`
  already call the V0 state through the existing production UI path.
- `HaloController`, `HaloEditorBridge`, `ShadowSearchService`, and
  `ShadowPanel` exist and are tested, but the full V1 editor mount would require
  protected editor edits.
- `AppBootstrap.initializeShadowBackendIfReady()` already opens a
  `RustShadowFFIClient` and creates a `ShadowIndexingService` for the active
  vault.

## Files Approved

- `Epistemos/State/ContextualShadowsState.swift`
- `Epistemos/Views/Recall/ContextualShadowsPanel.swift`
- `Epistemos/App/AppBootstrap.swift`
- `EpistemosTests/ContextualShadowsStateTests.swift`
- `docs/fusion/deliberation/halo_v0_shadow_backend_route_pr1_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_040_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`

## Files Forbidden

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- production FFI replacement code
- generated Swift/header bindings
- generated libraries
- Xcode project files
- entitlements
- DerivedData, `.xcresult`
- stash, branch, staging, commit, or destructive git operations

## Implementation Contract

- Existing V0 callers must not change.
- No per-keystroke disk/body load cascade.
- No main-thread heavy retrieval.
- Shadow search must happen through the existing `ShadowSearchServicing` async
  boundary.
- Recall cards must preserve and display source/provenance.
- If the implementation requires protected editor edits, stop and open a
  separate protected-path gate.

## Tests

Red/green command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ContextualShadowsStateTests test
```

Guardrails:

```bash
git diff --check -- Epistemos/State/ContextualShadowsState.swift Epistemos/Views/Recall/ContextualShadowsPanel.swift Epistemos/App/AppBootstrap.swift EpistemosTests/ContextualShadowsStateTests.swift docs/fusion
git diff --name-only -- Epistemos/Views/Notes/ProseEditorRepresentable2.swift Epistemos/Views/Notes/ProseEditorView.swift Epistemos/Views/Notes/ProseTextView2.swift Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Views/Graph/HologramController.swift graph-engine
```

## Rollback

Revert only the Contextual Shadows state route, panel source display, AppBootstrap
Shadow search configuration, tests, and docs for this slice. The existing V0
InstantRecall path must remain intact after rollback.

## Stop Triggers

- Any need to edit protected editor files.
- Any need to alter graph-engine or renderer internals.
- Shadow results without visible source/provenance.
- A change that removes the InstantRecall fallback.

## Execution Result

Status: accepted for the test/source-guard evidence commit.

Fresh verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ContextualShadowsStateTests test | tee /tmp/epistemos-contextual-shadows-v0-backend-source-mirror-20260501.log
```

Result:

- Swift Testing: 17 tests in 1 suite passed.
- The focused suite proves the configured `ShadowSearchServicing` backend feeds the production V0 recall state.
- Source guards prove V0 remains the production-mounted Contextual Shadows route and does not silently mount V1 `HaloController`.
- Source guards prove recall cards display source provenance and AppBootstrap guards stale Shadow backend/page reindex writes during vault switches.
- Xcode result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_22-58-00--0500.xcresult`.
- Xcode printed the inherited SwiftLint plugin failures for `CodeEditTextView` and `CodeEditSourceEditor` after `** TEST SUCCEEDED **`; this is existing package-plugin debt, not caused by this slice.
