# Halo Live-Loop Tests Deliberation - 2026-04-30

## Gate

Approved next action: **tests-only evidence slice**.

No production source edits are approved by this deliberation. No protected-path edits are approved. No Kimi code edits are approved.

## Context

The green floor and dirty-diff boundary are recorded in:

- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/DIRTY_DIFF_STABILIZATION_AUDIT_2026_04_30.md`

The next queue item from `docs/fusion/FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md` is Halo live-loop audit and minimal V1 proof.

Codex performed a shell/code audit and supervised a Terminal Kimi read-only audit. Antigravity Kimi remains stale and is not trusted for writes. Terminal Kimi was usable in plan mode, but it attempted an out-of-repo `mkdir -p /Users/jojo/.kimi/plans`; the action was rejected and no repo files changed. The session was closed.

## Evidence Commands

- `rg -n "HaloController|HaloEditorBridge|ShadowSearchService|ContextualShadows|ShadowPanel|contextualShadow|halo" ...`
- targeted reads of:
  - `Epistemos/Engine/HaloController.swift`
  - `Epistemos/Engine/HaloEditorBridge.swift`
  - `Epistemos/Engine/ShadowSearchService.swift`
  - `Epistemos/State/ContextualShadowsState.swift`
  - `Epistemos/Views/Recall/ContextualShadowsButton.swift`
  - `Epistemos/Views/Recall/ContextualShadowsPanel.swift`
  - `Epistemos/Views/Halo/ShadowPanel.swift`
  - `Epistemos/Views/Halo/ShadowPanelContent.swift`
  - `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
  - `Epistemos/Views/Chat/ChatInputBar.swift`
  - `Epistemos/App/AppBootstrap.swift`
  - `Epistemos/App/AppEnvironment.swift`
- focused verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/HaloControllerTests -only-testing:EpistemosTests/HaloEditorBridgeTests -only-testing:EpistemosTests/HaloUITests -only-testing:EpistemosTests/ContextualShadowsStateTests test
```

Result:

- Log: `/tmp/epistemos-halo-contextual-focused-20260430.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_17-14-55--0500.xcresult`
- Swift Testing: `51` tests in `4` suites passed after `0.495` seconds.
- Xcode reported `** TEST SUCCEEDED **`.
- The familiar SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` appeared after success; record as existing lint/build-script debt.

## Findings

There are two related but distinct recall surfaces.

### Production-Wired Surface: Contextual Shadows V0

The production-mounted surface today is:

`ContextualShadowsState -> ContextualShadowsButton -> ContextualShadowsPanel`

Evidence:

- `Epistemos/App/AppBootstrap.swift` instantiates `contextualShadowsState`.
- `Epistemos/App/AppEnvironment.swift` injects `bootstrap.contextualShadowsState`.
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` reads `ContextualShadowsState` from the environment and mounts `ContextualShadowsPanel` plus `ContextualShadowsButton` as a bottom-trailing overlay.
- `Epistemos/Views/Chat/ChatInputBar.swift` reads `ContextualShadowsState`, schedules debounced recall on composer text changes, renders `ContextualShadowsButton`, and mounts `ContextualShadowsPanel`.
- `Epistemos/Views/Notes/ProseEditorRepresentable2.swift` schedules contextual-shadows recall from editor text changes. This is evidence only; this protected file is not approved for edits.

Current backend:

- `ContextualShadowsState.requestRecall(snapshot:instantRecall:)` calls `InstantRecallService.searchAsync(...)`.
- The production V0 path does not call `ShadowSearchService` or `HaloController`.

### Tested/Scaffolded Surface: Halo V1

The V1 Halo scaffold exists and is well-tested, but it is not production-mounted.

Evidence:

- `HaloController` implements the state machine, debounce, score filtering, query extraction, and panel-open transitions.
- `HaloEditorBridge` can attach an `NSTextView` delegate and feed the controller.
- `ShadowPanelController` implements non-activating panel lifecycle and trailing-edge anchor math.
- `ShadowPanelContent` and `HaloButton` exist.
- Search for `HaloController(`, `ShadowPanelController(`, `HaloButton(`, and `HaloEditorBridge(` in `Epistemos/` found no production call sites, only tests/scaffold references.

The earlier T+5 trailing-edge anchor risk is already addressed in `ShadowPanelController.panelOrigin(...)` and covered by `HaloUITests`. That fix is not user-visible until a production caller exists.

### Rust Shadow Backend

The Rust shadow backend is initialized by bootstrap, but currently appears orphaned from the production UI surface.

Evidence:

- `ShadowSearchService` wraps `ShadowFFIClient`.
- `RustShadowFFIClient`, `ShadowIndexingService`, and `ShadowVaultBootstrapper` exist.
- `AppBootstrap` has shadow backend initialization paths.
- The production `ContextualShadowsState` path still takes `InstantRecallService`, not `ShadowSearchService`.

## Decision

Proceed with a **tests-only evidence slice** before implementation.

Rationale:

- The production V0 surface is mounted and flag-gated, so tests can increase confidence without changing behavior.
- The V1 Halo scaffold cannot be fully wired into the note editor without touching protected `ProseEditor*` paths.
- The Rust shadow backend needs a standalone smoke proof before it should be wired into the production surface.
- The current green floor should be preserved.

## Approved Files For Tests-Only Slice

Allowed test files:

- `EpistemosTests/ContextualShadowsStateTests.swift`
- `EpistemosTests/HaloUITests.swift`
- `EpistemosTests/HaloControllerTests.swift`
- `EpistemosTests/HaloEditorBridgeTests.swift`
- `EpistemosTests/ShadowServicesTests.swift`
- `EpistemosTests/ShadowVaultBootstrapperTests.swift`
- A new `EpistemosTests/*Shadow*Tests.swift` file if needed.

Allowed docs:

- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md` for appending evidence.
- `docs/fusion/deliberation/` for gate notes.

Allowed production reads, not edits:

- `Epistemos/State/ContextualShadowsState.swift`
- `Epistemos/Views/Recall/ContextualShadowsPanel.swift`
- `Epistemos/Views/Recall/ContextualShadowsButton.swift`
- `Epistemos/Engine/ShadowSearchService.swift`
- `Epistemos/Engine/ShadowFFIClient.swift`
- `Epistemos/Engine/RustShadowFFIClient.swift`
- `Epistemos/Engine/ShadowIndexingService.swift`
- `Epistemos/Engine/ShadowVaultBootstrapper.swift`
- `Epistemos/Models/HaloState.swift`
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
- `Epistemos/Views/Chat/ChatInputBar.swift`
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/App/AppEnvironment.swift`

## Forbidden Files And Actions

Forbidden without a separate gate:

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- graph-engine physics/render internals
- broad `graph-engine/` or `agent_core/` behavior changes
- worktree raw merge
- stash pop/apply/drop
- generated artifact cleanup
- staging, commits, branch changes

Do not use Kimi AFK/Yolo/print auto-approval for this slice.

## Target Test Evidence

The tests-only slice should attempt the safest evidence first:

1. Prove `ContextualShadowsState` result conversion and panel-state behavior remains correct for mixed note/chat hits.
2. Prove `ContextualShadowsState` cancellation/backpressure does not apply stale results.
3. Prove the Rust shadow search service path can return non-empty results through mock or local test FFI without touching production UI.
4. Add source-guard tests that document the current split:
   - `ContextualShadowsState` is production-mounted in notes/chat.
   - `HaloController`/`ShadowPanelController` currently have no production instantiation.
   - `ContextualShadowsState` still routes through `InstantRecallService`, not `ShadowSearchService`.

If any target test requires changing production code, stop and create a new narrow implementation deliberation. Do not silently convert this into a production-edit gate.

## Verification Commands

Focused command after test edits:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/HaloControllerTests -only-testing:EpistemosTests/HaloEditorBridgeTests -only-testing:EpistemosTests/HaloUITests -only-testing:EpistemosTests/ContextualShadowsStateTests -only-testing:EpistemosTests/ShadowServicesTests -only-testing:EpistemosTests/ShadowVaultBootstrapperTests test
```

Guardrail command:

```bash
git diff -- Epistemos/Views/Notes/ProseEditor\*.swift Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Views/Graph/HologramController.swift
```

Full floor may be rerun after the focused slice if test files change and focused evidence passes.

## Manual Verification Required Before Product Claim

No product-ready Halo/Contextual Shadows claim is allowed until manual/runtime evidence exists:

- Launch with `EPISTEMOS_AMBIENT_RECALL_V0=1`.
- Type in a note and confirm the contextual shadows affordance appears without typing jank.
- Open the panel and confirm it shows related notes with provenance-like title/snippet/score.
- Type in the chat composer and confirm the same flow appears there.
- Confirm note hits open through `NoteWindowManager.shared.open(pageId:)`.
- Confirm chat hits open through `MiniChatWindowController.shared.openChat(_:)`.

## Acceptance Criteria

- New tests are test-only or source-guard only.
- Focused test slice passes.
- Protected-path diff remains empty.
- The test evidence clearly states that V0 Contextual Shadows is production-mounted while V1 Halo is scaffolded/unmounted.
- No source production behavior changes are made under this gate.

## Stop Triggers

- A test cannot be written without production source changes.
- Any need appears to edit `ProseEditor*`.
- Any attempt to wire `HaloEditorBridge` into the note editor.
- Any FFI test crashes or leaks in a way that requires product behavior changes.
- Any Kimi tool call requests writes, shell mutation, stash, clean, stage, commit, or branch operations.
- Any protected-path drift appears.

## Execution Result

Status: **accepted for tests-only evidence**.

Files changed:

- `EpistemosTests/ContextualShadowsStateTests.swift`
- `EpistemosTests/HaloUITests.swift`

Added evidence:

- `ContextualShadowsState` clears stale visible results for short queries.
- `ContextualShadowsState` preserves the current V0 note/chat hit contract through `InstantRecallService`.
- Source guards document that V0 Contextual Shadows is production-mounted in app bootstrap, app environment, notes, chat, and editor recall scheduling.
- Source guards document that V0 currently routes through `InstantRecallService`, not `ShadowSearchService` or `HaloController`.
- `ShadowPanelController.panelOrigin(...)` now has explicit tests for trailing-edge placement, left flip, viewport clamps, and custom gap math.
- Source guards document that V1 `HaloController`, `HaloEditorBridge`, `ShadowPanelController`, and `HaloButton` are scaffolded/tested but not production-instantiated outside the Halo scaffold files.

Focused verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/HaloControllerTests -only-testing:EpistemosTests/HaloEditorBridgeTests -only-testing:EpistemosTests/HaloUITests -only-testing:EpistemosTests/ContextualShadowsStateTests -only-testing:EpistemosTests/ShadowServicesTests -only-testing:EpistemosTests/ShadowVaultBootstrapperTests test
```

- Log: `/tmp/epistemos-halo-contextual-tests-only-20260430.log`
- Exit code `0`.
- Swift Testing: `72` tests in `6` suites passed after `4.453` seconds.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_17-28-50--0500.xcresult`

Full-floor follow-up:

- Default full rerun failed with two non-Halo failures and a test-host restart:
  `/tmp/epistemos-full-test-after-halo-contextual-tests-20260430.log`
- The two failures passed in focused repro:
  `/tmp/epistemos-full-rerun-failures-focused-20260430.log`
- Serial full rerun passed:
  `/tmp/epistemos-full-test-serial-after-halo-contextual-tests-20260430.log`
- Serial result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_17-44-07--0500.xcresult`
- Serial Swift Testing summary: `5024` tests in `563` suites passed after `215.970` seconds.

Guardrails:

- `git diff --check` was clean for the changed test/doc scope.
- Protected-path diff remained empty for:
  - `Epistemos/Views/Notes/ProseEditor*.swift`
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `Epistemos/Views/Graph/HologramController.swift`
- No production source edits, staging, commits, stash operations, or branch operations were performed.

Kimi oversight:

- `docs/fusion/KIMI_FUSION_REVIEW_2026_04_30.md` exists and is usable as Phase 0 inventory input.
- Correction required before further Kimi work: Kimi did not list `CLAUDE.md`, even though the overseer prompt required reading it if present and `CLAUDE.md` does exist.
- Correction required before further Kimi work: Kimi's build-floor status is stale relative to the later raw logs recorded in `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`.
- Codex created `docs/fusion/KIMI_FUSION_REVIEW_ADDENDUM_2026_04_30.md` after Kimi's correction attempt wrote a forbidden `/Users/jojo/.kimi/plans/...` plan file and was stopped.
- Kimi remains blocked from code edits until a new implementation deliberation gate is approved.

Next gate:

- Do not claim Halo or Contextual Shadows product readiness yet.
- Manual/runtime verification remains required before a product-facing claim.
- A separate implementation deliberation is required before wiring V1 Halo, replacing V0 backend routing, or touching any protected editor path.
