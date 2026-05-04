# Halo / Contextual Shadows Audit-Defer Deliberation - 2026-04-30

## Gate

Approved action: **audit current Halo and Contextual Shadows wiring, run focused automated coverage, and defer production V1 or backend rewiring until a separate implementation gate**.

This gate approves documentation and automated/source verification only. It does not approve mounting V1 Halo in production, switching V0 Contextual Shadows from `InstantRecallService` to `ShadowSearchService`, editing protected note-editor files, or performing manual app verification.

## Context

The fusion queue marks Halo as the V1 wedge and flags uncertainty around the live debounce-to-search-to-panel path. The Kimi addendum narrows that uncertainty:

- V0 Contextual Shadows is production-mounted in app bootstrap, app environment, notes, chat, and editor recall scheduling.
- V0 currently routes through `InstantRecallService`.
- V1 Halo (`HaloController`, `HaloEditorBridge`, `ShadowPanelController`, `HaloButton`) is scaffolded and tested, but not production-instantiated.
- `ShadowSearchService` and the Rust shadow backend exist, but are not the current production UI route for V0.

The user explicitly deferred manual app verification for now, so this slice may prove automated/source facts but must not claim final product-facing runtime readiness.

## Decision

Keep V0 Contextual Shadows as-is for this checkpoint and record the current evidence:

- Confirm production mount/source routing through `rg`.
- Run focused Contextual Shadows and Halo controller/editor/panel tests.
- Treat V1 Halo mounting or backend rewiring as a future implementation gate with a fresh file list and stop triggers.
- Do not edit `ProseEditor*`, graph render/physics files, or production panel/controller code in this audit slice.

## Core/Pro Classification

Classification: **Core**.

Contextual Shadows is a Core recall surface. V1 Halo may later become a more advanced differentiator, but any routing change must preserve Core safety and performance budgets before Pro-only expansion is considered.

## Files Approved

- `docs/fusion/deliberation/halo_contextual_shadows_audit_defer_deliberation_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_012_2026_04_30.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

## Files Forbidden

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/` physics/render internals
- `Epistemos/Engine/HaloController.swift`
- `Epistemos/Engine/HaloEditorBridge.swift`
- `Epistemos/Engine/ShadowSearchService.swift`
- `Epistemos/State/ContextualShadowsState.swift`
- `Epistemos/Views/Halo/`
- `Epistemos/Views/Recall/ContextualShadowsPanel.swift`
- `EpistemosTests/HaloControllerTests.swift`
- `EpistemosTests/HaloEditorBridgeTests.swift`
- `EpistemosTests/HaloUITests.swift`
- `EpistemosTests/ContextualShadowsStateTests.swift`
- stash mutation, branch extraction, checkout, staging, commits, generated artifacts, project files, entitlements, DerivedData, or `.xcresult` bundles

## Alternatives Considered

- Mount V1 Halo now: rejected because V1 is not production-instantiated and likely requires protected editor integration or a new production route decision.
- Switch V0 to `ShadowSearchService` now: rejected because the addendum requires a separate backend/V1 deliberation.
- Run manual app verification now: rejected for this slice because the user explicitly asked to postpone manual testing.
- Apply or mine donor worktrees for Halo UI changes: rejected because current source already has tested scaffold coverage and no donor write scope was approved.

## Tests

Focused automated coverage:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/HaloControllerTests -only-testing:EpistemosTests/HaloEditorBridgeTests -only-testing:EpistemosTests/HaloUITests -only-testing:EpistemosTests/ContextualShadowsStateTests test
```

Required evidence:

- Contextual Shadows V0 production mount/source guard passes.
- V0 still routes through `InstantRecallService`, not the Halo shadow backend.
- V1 Halo scaffold is not silently mounted in production views.
- Halo controller/editor/panel tests pass.

## Rollback

No production code rollback is expected because this is an audit-only slice. If documentation is wrong, correct only the approved docs files.

## Stop Triggers

- Any need to edit `ProseEditor*` or protected graph/render files.
- Any need to alter production recall routing.
- Any failure in focused Halo/Contextual automated coverage.
- Any desire to claim product-facing runtime readiness without manual app verification.

## Kimi

Kimi may provide read-only advisory critique only. Kimi is not approved to edit code, apply stashes, stage, commit, or perform write-scope implementation.
