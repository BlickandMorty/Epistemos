# Mutation Envelope EventStore Deliberation

Date: 2026-04-30
Owner: Codex overseer
Status: Approved for narrow implementation

## Context

The Quick Capture typed artifact slice now returns a committed `MutationEnvelope` and records its JSON in the capture trace stream. The next fusion queue item is Raw Thoughts / Provenance Spine hardening, but the Rust substrate is not safe for broad edits yet:

- `agent_core/src/oplog.rs` is already dirty.
- `agent_core/src/mutations/` and `agent_core/src/provenance/` are untracked in this worktree.
- The Swift `MutationEnvelope` parity files are also untracked in the current branch state.

Current Swift trunk already has `EventStore`, an app-level SQLite store used for durable session events, snapshots, captured artifacts, Night Brain checkpoints, and conversation/session telemetry.

## Decision

Implement the smallest Swift-only durability bridge:

- Add a `mutation_envelopes` table to `EventStore`.
- Add synchronous `saveMutationEnvelope` and `loadMutationEnvelope` helpers.
- Store full sorted JSON plus useful indexed columns: mutation ID, trace ID, status, artifact ID, artifact kind, and integrity hash.
- Inject an `EventStore` provider into `TextCapturePipeline` with a default of `EventStore.shared`.
- When Quick Capture creates a mutation envelope, synchronously write it to `EventStore` before returning the `CaptureResult` when a store is available.
- Expose whether persistence succeeded in `CaptureResult`.

## Allowed Files

- `Epistemos/State/EventStore.swift`
- `Epistemos/Engine/TextCapturePipeline.swift`
- `EpistemosTests/TextCapturePipelineTests.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift` only if a table-level guard is more natural than the capture test
- Fusion docs/results only

## Forbidden Files

- `agent_core` edits in this slice
- `graph-engine` edits
- Raw branch/stash/worktree merges
- Pro-only browser/computer-use/Hermes surfaces
- Protected editor and graph-render files

## Test Plan

- Failing-first Swift test that a capture with an injected `EventStore` returns `mutationEnvelopePersisted == true` and can load the same envelope by mutation ID.
- Failing-first EventStore schema/test coverage if needed.
- Targeted test run:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/TextCapturePipelineTests -only-testing:EpistemosTests/CognitiveSubstrateTests/EventStoreSchemaTests -only-testing:EpistemosTests/MutationEnvelopeParityTests test`
- Guardrails:
  `git diff --check` for touched files and empty protected-path diff.

## Stop Triggers

- Any need to modify dirty `agent_core` files.
- Any persistence path that writes asynchronously while still claiming durable success.
- Any mutation envelope wire-format change.
- Any protected editor or graph-render edit.

## Manual Runtime

Deferred by user request. Later runtime verification should trigger Quick Capture and confirm the created note, trace event, and EventStore mutation envelope row align on the same mutation ID.

## Result

Implemented as the approved Swift-only bridge:

- `EventStore` now creates `mutation_envelopes` with indexed trace and artifact columns.
- `EventStore.saveMutationEnvelope(_:traceId:)` synchronously writes sorted envelope JSON and returns durable success/failure.
- `EventStore.loadMutationEnvelope(mutationID:)` decodes the stored JSON for parity-safe round-trip checks.
- `TextCapturePipeline` accepts an injected `EventStore` provider and exposes `mutationEnvelopePersisted`.
- The capture path records the same committed envelope to the trace stream and, when available, the durable EventStore row.

Verification:

- Red log: `/tmp/epistemos-mutation-envelope-eventstore-red-20260430.log`
- Green log: `/tmp/epistemos-mutation-envelope-eventstore-green-20260430.log`
- Green result: `50` tests in `2` suites passed after `0.530` seconds.
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_18-25-30--0500.xcresult`

Codex reverification on 2026-05-01:

- TextCapture focused run: `/tmp/epistemos-w1011-brain-dump-intent-reverify-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_22-21-04--0500.xcresult`
- Result: `41` `TextCapturePipelineTests` passed, including the mutation-envelope capture path.
- Mutation envelope parity run: `/tmp/epistemos-mutation-envelope-eventstore-reverify-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_22-32-06--0500.xcresult`
- Result: `13` `MutationEnvelopeParityTests` passed.
