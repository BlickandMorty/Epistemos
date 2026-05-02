# W10.8 Cognitive Depth Overlay Deliberation — 2026-04-30

## Gate

Approved for a minimal Core/MAS-safe overlay contract repair.

## Classification

Core/MAS-safe.

## Scope

- Verify the existing `CognitiveDepthOverlay` Phase 8 implementation instead of re-building it.
- Add focused automated coverage for missing sidecars, sidecar-backed depth, corrupt-sidecar fallback, pending preview overrides, and visualization hierarchy.
- Fix only the discovered pending-preview precedence bug if the red test proves it.
- Avoid protected graph-renderer edits; MetalGraphView is already wired and remains non-scope.

## Explicit Non-Scope

- No protected `MetalGraphView.swift`, `HologramController.swift`, note editor, graph-engine/Rust, project, entitlement, generated artifact, branch, stash, staging, or commit edits.
- No UI inspector, manual app verification, graph screenshot verification, ETL crawler, or vault migration in this slice.
- No semantic changes to `DepthMarker`, `EpistemosSidecar`, or the graph FFI boundary unless a focused compile failure proves a local need.

## Evidence Before Edit

- `CognitiveDepthOverlay` already exists and reads `EpistemosSidecar.depth`.
- `MetalGraphView` already has an `applyCognitiveDepthOverlay(...)` path for visible note nodes.
- `CognitiveDepthOverlay.setDepth(..., persist: false)` documents preview behavior, but `depth(for:)` checks the cached value before pending overrides.
- There were no focused `CognitiveDepthOverlay` tests before this slice.

## Decision

Treat W10.8 as a verification/hardening slice. The primary risk is not missing implementation, but an untested preview-state precedence bug that can make an inspector preview appear ignored after the note depth has already been cached.

## Test Plan

- Add `CognitiveDepthOverlayTests` proving:
  - missing sidecar defaults to `.surface`;
  - sidecar `depth` drives lookup;
  - pending preview override wins over an already-cached sidecar until discarded;
  - corrupt sidecar JSON falls back to `.surface`;
  - altitude and radius mappings preserve the L1 to L3 hierarchy.
- Run:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/CognitiveDepthOverlayTests test`

## Stop Triggers

- Any need to edit protected graph renderer/controller files or graph-engine/Rust.
- Any need to change project files or generated artifacts.
- Any evidence that the overlay cannot be verified without manual runtime graph inspection.

## Result

Red verification failed exactly on the preview precedence contract:

- Log: `/tmp/epistemos-w1008-cognitive-depth-overlay-red-20260430.log`
- Result: `** TEST FAILED **`
- Expected failure: `Pending preview override wins over cached sidecar until discarded` returned cached `.surface` instead of pending `.coreBelief`.

Implemented the minimal fix:

- `CognitiveDepthOverlay.depth(for:)` now checks `pendingOverrides` before cached sidecar depth.
- The source-of-truth comment now matches that runtime behavior.
- No protected graph renderer/controller, graph-engine/Rust, project, entitlement, generated artifact, stash, branch, staging, or commit changes were made.

Green verification passed:

- Log: `/tmp/epistemos-w1008-cognitive-depth-overlay-green-20260430.log`
- Result: `** TEST SUCCEEDED **`
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_22-19-13--0500.xcresult`
- Swift Testing result: `5` tests passed in `1` suite.

Codex reverification before staging also passed:

- Log: `/tmp/epistemos-w1008-cognitive-depth-overlay-reverify-20260501.log`
- Result: `** TEST SUCCEEDED **`
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_22-16-29--0500.xcresult`
- Swift Testing result: `5` tests passed in `1` suite.
- Protected diff audit still reports unrelated pre-existing dirty graph-engine files (`forces.rs`, `renderer.rs`, `simulation.rs`); this slice does not stage or claim them.
