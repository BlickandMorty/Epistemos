# Quick Capture Typed Artifact Current-State Deliberation - 2026-05-01

## Gate

Approved action: **current-state closeout for Card 4**.

No production implementation is approved by this brief because the requested
minimal Quick Capture typed-artifact path is already present in current code.
This brief records the evidence, focused tests, Kimi advisory result, and
remaining non-blocking gaps.

## Queue Item

Source:

- `docs/fusion/FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md` lines 64-78
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
  lines 230-272

Required contract:

- Preserve verbatim user input.
- Route the user gesture through the typed capture pipeline rather than loose
  markdown-only state.
- Emit or link a typed provenance artifact before user-visible success.
- Keep Core/MAS paths free of shell, Docker, external CLI, or Pro-only tools.
- Do not raw-merge the Quick Capture donor worktree.

## Evidence

Quick Capture sheet:

- `Epistemos/Views/Capture/QuickCaptureView.swift:500` calls
  `pipeline.run(rawText:modelContext:)`.
- `Epistemos/Views/Capture/QuickCaptureView.swift:504-511` requires a
  persisted note and `result.mutationEnvelopePersisted` before assigning the
  success `captureResult`.
- `Epistemos/Views/Capture/QuickCaptureView.swift:532` calls
  `pipeline.runFromAudio(transcription:modelContext:)`.
- `Epistemos/Views/Capture/QuickCaptureView.swift:533-540` applies the same
  persisted-note and durable-envelope guards for audio capture.

Quick Capture App Intent:

- `Epistemos/Intents/Custom/NoteActionIntents.swift:38-41` routes the shortcut
  through `bootstrap.textCapturePipeline.run(rawText:modelContext:)`.
- `Epistemos/Intents/Custom/NoteActionIntents.swift:43-48` requires
  `createdNoteID` and `mutationEnvelopePersisted` before
  `NoteWindowManager.shared.open(pageId:)`.

Typed artifact and provenance:

- `Epistemos/Engine/TextCapturePipeline.swift:77-91` exposes
  `CaptureResult.createdNoteID`, `mutationEnvelope`,
  `mutationEnvelopePersisted`, and `traceID`.
- `Epistemos/Engine/TextCapturePipeline.swift:288-307` persists the note when
  a `ModelContext` is supplied.
- `Epistemos/Engine/TextCapturePipeline.swift:310-333` writes note/entity graph
  projection and records the graph write attempt.
- `Epistemos/Engine/TextCapturePipeline.swift:335-362` creates a
  `MutationEnvelope`, saves it through `EventStore.saveMutationEnvelope`, and
  records `mutationEnvelopeCommitted`.
- `Epistemos/Engine/TextCapturePipeline.swift:386-421` constructs the committed
  prose-note `MutationEnvelope` with artifact id, kind, integrity hash, and
  affected projections.
- `Epistemos/State/EventStore.swift:455-470` begins durable envelope encoding
  in `saveMutationEnvelope(_:traceId:)`.
- `Epistemos/State/EventStore.swift:1391-1445` inserts the committed envelope
  into the mutation projection outbox with trace id, artifact id, artifact kind,
  status, and integrity hash.

Test evidence:

- `EpistemosTests/TextCapturePipelineTests.swift:240-284` proves persisted
  capture writes the envelope to the injected `EventStore`, loads it back, and
  writes a trace-linked outbox row.
- `EpistemosTests/TextCapturePipelineTests.swift:750-776` proves the trace
  records committed envelope JSON with committed status, artifact id, and
  artifact kind.
- `EpistemosTests/TextCapturePipelineTests.swift:828-853` proves both the sheet
  and shortcut success paths require durable mutation-envelope persistence
  before claiming success.
- `EpistemosTests/MutationEnvelopeParityTests.swift:140-184` guards canonical
  wire fields and schema-version lockstep.

## Kimi Advisory

Terminal Kimi read-only advisory log:

- `/tmp/epistemos-quick-capture-typed-artifact-kimi-advisory-20260501.log`
- Resume id: `7ce7fd42-0d78-469f-91bb-1c1006cce956`

Kimi independently confirmed all four Card 4 criteria:

- UI and App Intent route through `TextCapturePipeline`.
- Sheet, audio, and App Intent paths require `createdNoteID` and
  `mutationEnvelopePersisted` before success/opening.
- `TextCapturePipeline` persists `MutationEnvelope` to `EventStore` with trace.
- Existing tests cover EventStore persistence, trace JSON, UI/intent guards,
  and parity.

Operational note:

- The first Kimi invocation used `--final-message-only --plan` and stalled with
  a zero-byte log; Codex killed that read-only terminal process and retried with
  streaming `--print`. No repo files changed during either Kimi attempt.

## Decision

Status: **Card 4 closes as already-current**.

No new production code is needed for the minimal typed-artifact vertical slice.
Adding another scaffold or donor-worktree merge would duplicate the canonical
pipeline that is already wired through `TextCapturePipeline`,
`MutationEnvelope`, and `EventStore`.

## Verification

Focused Quick Capture suite:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/TextCapturePipelineTests test
```

- Log:
  `/tmp/epistemos-quick-capture-typed-artifact-text-capture-tests-20260501.log`
- Result: `41` tests in `1` suite passed.
- Xcode reported `** TEST SUCCEEDED **`.

Focused mutation envelope parity suite:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/MutationEnvelopeParityTests test
```

- Log:
  `/tmp/epistemos-quick-capture-typed-artifact-mutation-envelope-parity-tests-20260501.log`
- Result: `13` tests in `1` suite passed.
- Xcode reported `** TEST SUCCEEDED **`.

## Guardrails

- No production files were changed by this closeout.
- No Quick Capture donor worktree code was raw-merged.
- No protected note editor files, graph renderer/controller files,
  `graph-engine/**`, generated artifacts, project files, entitlements, branch
  state, stash state, staging, or commits were changed.
- The protected `graph-engine/**` dirty diff remains inherited branch state and
  unrelated to this Card 4 closeout.
- Xcode still reported inherited SwiftLint command failures for
  `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`;
  this remains plugin/lint noise, not a Card 4 blocker.

## Remaining Gaps

- Manual runtime verification of the sheet and shortcut was intentionally
  deferred by the user for this phase.
- Rust `RunEventLog`/BLAKE3 chain verification remains a separate provenance
  hardening slice, not part of this minimal Quick Capture closeout.
- Broader donor-worktree ideas such as universal undo, route capture, and heal
  loops remain future implementation candidates only after separate gates.
