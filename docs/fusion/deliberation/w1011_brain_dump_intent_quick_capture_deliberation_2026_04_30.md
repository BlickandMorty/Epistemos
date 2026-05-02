# W10.11 Brain Dump Intent Quick Capture Deliberation — 2026-04-30

## Gate

Approved for a minimal Core/MAS-safe App Intent repair.

## Scope

- Make `CaptureBrainDumpIntent` with an empty body open the existing Quick Capture sheet so the user can dictate instead of silently doing nothing.
- Preserve the existing Quick Capture sheet, audio button, `TextCapturePipeline`, mutation-envelope durability, and App Intent registration.
- Add active-context anchoring for non-empty raw brain dumps when an active note or chat is available.
- Keep text brain dumps in `QuarantineArchive` for W10.15 raw-thought quarantine semantics.

## Explicit Non-Scope

- No raw Quick Capture worktree merge.
- No protected note editor, graph renderer, graph-engine, Rust, project, entitlement, or generated-file edits.
- No new global hotkey daemon, background audio recorder, menu-bar extra, widget extension target, or manual UI verification in this slice.
- No claim that W10.11 is fully product-verified without later runtime testing.

## Evidence Before Edit

- `QuickCaptureView` already supports text capture and dictation through `AudioRecorder`/`AudioTranscriber`.
- `EpistemosApp` already presents `QuickCaptureView` on `.showQuickCapture`.
- `EpistemosCommands` already exposes `Quick Capture` on `Command-Shift-N`.
- `CaptureBrainDumpIntent` is registered with Shortcuts/Spotlight, but its empty-body path returns without opening the capture UI.
- `CaptureBrainDumpIntent` non-empty path writes to `QuarantineArchive` with `anchor: nil`, despite the intent description promising current chat/note/raw-thought routing.

## Decision

Use the existing notification bridge for the empty-body path and keep all capture UI behavior centralized in `QuickCaptureView`. For non-empty body, resolve an active note anchor first, then active chat, then fall back to unanchored raw thought quarantine. Return a user-facing dialog so Spotlight/Shortcuts does not look like a no-op.

## Test Plan

- Add failing source-mirror tests proving:
  - empty `CaptureBrainDumpIntent` posts `.showQuickCapture`;
  - non-empty `CaptureBrainDumpIntent` resolves active note/chat context before writing to `QuarantineArchive`.
- Run:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/TextCapturePipelineTests test`

## Stop Triggers

- Implementation requires protected editor/graph paths, graph-engine, Rust, project files, entitlements, generated artifacts, branch/stash actions, or UI redesign.
- `CaptureBrainDumpIntent` can no longer build in the App Store/MAS path.
- Quick Capture durable-success guards are weakened.

## Verification Result

- Red log: `/tmp/epistemos-w1011-brain-dump-intent-red-20260430.log`
  - Result: `** TEST FAILED **`
  - Expected source-mirror failures:
    - empty body did not post `.showQuickCapture`;
    - raw-thought capture did not resolve an active note/chat anchor.
- Green log: `/tmp/epistemos-w1011-brain-dump-intent-green-20260430.log`
  - Result: `** TEST SUCCEEDED **`
  - Swift Testing result: `41` tests passed in `1` suite.
  - Result bundle:
    `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_21-53-49--0500.xcresult`
- Source audit log: `/tmp/epistemos-w1011-brain-dump-intent-source-audit-20260430.log`
- Tracked-source diff check log: `/tmp/epistemos-w1011-diff-check-20260430.log` (`0` bytes; no whitespace errors in tracked source/test files).
- Touched-file whitespace audit log: `/tmp/epistemos-w1011-whitespace-audit-20260430.log` (`0` bytes; no trailing whitespace in source/test/docs).
- Protected diff audit log: `/tmp/epistemos-w1011-protected-diff-audit-20260430.log`
  - Reports pre-existing dirty `graph-engine/src/renderer.rs`.
  - This slice did not edit protected graph/editor files and did not apply/revert that protected diff.

## Codex Reverification - 2026-05-01

Re-ran the focused suite before staging this slice:

- Command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/TextCapturePipelineTests test`
- Log: `/tmp/epistemos-w1011-brain-dump-intent-reverify-20260501.log`
- Result: `** TEST SUCCEEDED **`
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_22-21-04--0500.xcresult`
- Swift Testing result: `41` tests passed in `1` suite.

Staging note: `EpistemosTests/TextCapturePipelineTests.swift` also contains unrelated dirty mutation-envelope tests in the working tree. The W10.11 commit stages only the two brain-dump intent source-guard tests and leaves the unrelated test work unstaged.
