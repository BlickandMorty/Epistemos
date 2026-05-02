# Deliberation Brief - Quick Capture Durable Success Honesty

Date: 2026-04-30
Owner: Codex overseer
Status: Approved for narrow implementation

## A. Repo Evidence

- `TextCapturePipeline` now returns `CaptureResult.mutationEnvelopePersisted`.
- `TextCapturePipeline` only sets `mutationEnvelopePersisted == true` after `EventStore.saveMutationEnvelope(_:traceId:)` succeeds.
- `QuickCaptureView.submitCapture()` and `toggleAudioRecording()` currently guard `createdNoteID` before presenting the success confirmation, but do not guard `mutationEnvelopePersisted`.
- `QuickCaptureIntent.perform()` currently guards `createdNoteID` before opening the note and returning a success dialog, but does not guard `mutationEnvelopePersisted`.
- The preceding outbox slices made committed envelope persistence and cold projection enqueueing durable in app-level `EventStore`; Rust `RunEventLog` remains deferred.

## B. Research Evidence

- `docs/_consolidated/00_canonical_authority/MASTER_FUSION.md` says not to emit UI success before durable state succeeds.
- `docs/fusion/RESEARCH_FUSION_NOTES_2026_04_30.md` repeats that UI success must not emit before durable commit succeeds.
- `docs/fusion/FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md` item 4 says Quick Capture must not bypass `MutationEnvelope`.
- `docs/fusion/FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md` item 5 says durable event ordering must be verified before UI success claims.

## C. Decision

Implement a narrow Core/MAS-safe honesty guard:

- Quick Capture UI success requires both a persisted note id and `mutationEnvelopePersisted == true`.
- Quick Capture App Intent success/opening requires both a persisted note id and `mutationEnvelopePersisted == true`.
- Audio Quick Capture confirmation uses the same durable-success guard.
- Failure should surface as a normal capture persistence failure, not as a success card/dialog.
- Do not change `TextCapturePipeline` commit semantics, EventStore schema, Rust, graph, editor, App Intent project wiring, or UI layout beyond the guard.

Core/Pro/Both: Core/MAS-safe Quick Capture.

## D. Alternatives

- Leave success guarded only on note creation: rejected because it can claim success after note persistence while provenance commit failed.
- Fail only App Intent and leave sheet UI permissive: rejected because the doctrine applies to all user-visible success surfaces.
- Make `TextCapturePipeline` throw on envelope persistence failure: rejected for this slice because dry-run/no-store capture behavior and tests need a dedicated broader gate.
- Bridge to Rust RunEventLog first: rejected because Rust provenance substrate is a separate dirty/high-risk slice.

## E. Reversal Triggers

- Guarding durable success requires `TextCapturePipeline` API changes.
- Guarding durable success breaks existing focused capture/envelope tests.
- The change requires protected editor, protected graph-render, graph-engine, Rust, project, entitlement, or generated-file edits.
- The implementation hides failures while still showing success UI.

## F. Patch Plan

Files:

- `Epistemos/Views/Capture/QuickCaptureView.swift`
- `Epistemos/Intents/Custom/NoteActionIntents.swift`
- `EpistemosTests/TextCapturePipelineTests.swift`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

Protected files:

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- graph physics/render internals
- `agent_core` and `graph-engine`

Tests:

- Add failing source-mirror tests proving `QuickCaptureView` checks `result.mutationEnvelopePersisted` before assigning `captureResult`.
- Add failing source-mirror test proving `QuickCaptureIntent` checks `result.mutationEnvelopePersisted` before opening the note/returning success.
- Run:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/TextCapturePipelineTests test`

Rollback:

- Revert `QuickCaptureView.swift`, `NoteActionIntents.swift`, focused tests, and this deliberation/results doc update.

Stop triggers:

- Any need to touch Rust, graph-engine, protected note editor, protected graph renderer, project files, entitlements, generated files, stashes, branches, staging, or commits.
- Any claim that this completes Rust RunEventLog/BLAKE3 chain verification.

## G. Result

Implemented the narrow durable-success guard.

- `QuickCaptureView.submitCapture()` now requires `result.mutationEnvelopePersisted` before assigning `captureResult`.
- `QuickCaptureView.toggleAudioRecording()` now applies the same guard before assigning audio capture success.
- `QuickCaptureIntent.perform()` now requires `result.mutationEnvelopePersisted` before opening the note or returning the success dialog.
- Added source-mirror tests that prove Quick Capture sheet and App Intent success paths require the durable mutation-envelope signal.

Verification:

- Red: `/tmp/epistemos-quick-capture-durable-success-red-20260430.log`
  - Exit code `65`.
  - Expected failing checks: missing `guard result.mutationEnvelopePersisted else` in the sheet and intent paths.
- Green focused: `/tmp/epistemos-quick-capture-durable-success-green-20260430.log`
  - Exit code `0`.
  - `39` tests in `1` suite passed.
  - Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_20-08-47--0500.xcresult`
- Wider final: `/tmp/epistemos-quick-capture-durable-success-final-20260430.log`
  - Exit code `0`.
  - `52` tests in `2` suites passed.
  - Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_20-11-37--0500.xcresult`

Post-slice guardrails:

- `git diff --check` passed for the touched Quick Capture, intent, test, deliberation, and results files.
- Protected-path diff audit remained empty for:
  - `Epistemos/Views/Notes/ProseEditor*.swift`
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `Epistemos/Views/Graph/HologramController.swift`
- No Rust, graph-engine, protected note editor, protected graph renderer, project, entitlement, generated-file, stash, branch, staging, or commit action was taken.
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains existing plugin/lint debt and not a compile/test blocker.

Codex reverification on 2026-05-01:

- Focused run: `/tmp/epistemos-quick-capture-durable-success-reverify-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_22-38-44--0500.xcresult`
- Result: `41` `TextCapturePipelineTests` passed, including the Quick Capture durable-success source guards.
- Xcode again printed the existing SwiftLint plugin failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; these remain non-blocking inherited plugin debt.
