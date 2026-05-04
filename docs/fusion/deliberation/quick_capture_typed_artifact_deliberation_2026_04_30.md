# Quick Capture Typed Artifact Deliberation

Date: 2026-04-30
Owner: Codex overseer
Status: Approved for narrow implementation

## Context

The fusion queue names Quick Capture as sibling-canonical, not a branch to merge. Current trunk already has a real text-first capture path:

- `QuickCaptureView` submits through `TextCapturePipeline`.
- `QuickCaptureIntent` submits through `TextCapturePipeline`.
- `TextCapturePipeline` persists `SDPage`, mirrors blocks, writes graph nodes/edges, records trace events, and returns `CaptureResult`.

The remaining gap for this slice is not UI plumbing. It is typed substrate evidence: the successful capture path should produce a `MutationEnvelope` for the created note artifact so downstream provenance, graph/index projection, and later RunEventLog hardening have a stable contract.

## Decision

Implement the smallest Core/MAS-safe capture-to-envelope proof:

- Add a committed `MutationEnvelope?` to `CaptureResult`.
- Build the envelope only after note persistence has succeeded.
- Populate it as an `artifact_create` for the created note ID with `ArtifactKind.proseNote`.
- Mark touched artifact, body/search/graph effects, committed status, user actor, reversible/internal metadata, and a non-empty integrity hash.
- Record the envelope JSON in the existing capture trace stream as a dedicated trace event.
- Leave full append-only RunEventLog/BLAKE3 chain integration for the Raw Thoughts / Provenance Spine slice, because the Swift app currently exposes `TraceCollector` for capture traces and `agent_core` oplog is a separate dirty Rust substrate.

## Allowed Files

- `Epistemos/Engine/TextCapturePipeline.swift`
- `Epistemos/Harness/TraceCollector.swift`
- `EpistemosTests/TextCapturePipelineTests.swift`
- Fusion docs/results only

## Forbidden Files

- Raw Quick Capture worktree merges
- `agent_core` / `graph-engine` changes in this slice
- Pro-only browser/computer-use/Hermes surfaces
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- Graph physics/render internals

## Test Plan

- Failing-first Swift test proving a persisted capture returns a committed mutation envelope.
- Failing-first Swift test proving the capture trace records a mutation-envelope event.
- Targeted test run:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/TextCapturePipelineTests -only-testing:EpistemosTests/MutationEnvelopeParityTests test`
- Diff guard:
  `git diff -- Epistemos/Views/Notes/ProseEditor\*.swift Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Views/Graph/HologramController.swift`

## Stop Triggers

- Envelope would be created before durable note save.
- Implementation requires raw branch/stash/worktree merge.
- Implementation requires protected editor or graph-render edits.
- MutationEnvelope wire format parity breaks.

## Manual Runtime

Deferred by user request. Later runtime verification should trigger menu-bar or App Intent Quick Capture and confirm the saved note appears in vault/sidebar/graph with provenance trace evidence.
