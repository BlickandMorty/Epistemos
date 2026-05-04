# Deliberation Brief - Mutation Projection Outbox Pending Reader

Date: 2026-04-30
Owner: Codex overseer
Status: Approved for narrow implementation

## A. Repo Evidence

- `EventStore` already stores committed `MutationEnvelope` JSON in `mutation_envelopes`.
- `EventStore` already enqueues one idempotent `mutation_projection_outbox` row for committed envelopes in the same SQLite transaction.
- `EventStore.mutationProjectionOutboxRows(mutationID:)` only supports mutation-specific test/audit lookup.
- No Swift `RunEventLog` bridge, `AgentEvent` projection bus, or graph/UI projector is approved in this slice.
- `agent_core/src/oplog.rs` already contains dirty/high-risk Rust BLAKE3 oplog code, so creating a parallel Swift RunEventLog would duplicate canonical provenance semantics.

## B. Research Evidence

- `docs/fusion/FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md` item 5 requires Raw Thoughts / Provenance Spine hardening but warns that dirty `agent_core` event/log files must be audited before edits.
- `docs/fusion/KIMI_FUSION_REVIEW_2026_04_30.md` preserves the product spine: `TypedArtifact -> MutationEnvelope -> RunEventLog -> AgentEvent -> GraphEvent`.
- `docs/fusion/deliberation/mutation_projection_outbox_deliberation_2026_04_30.md` explicitly stopped at a cold outbox queue and rejected full AgentEvent/GraphEvent UI projection.
- Terminal Kimi advisory was attempted for this slice but returned no usable output within the constrained step budget; Codex is proceeding under the same read-only Kimi rule.

## C. Decision

Implement the smallest consumer-facing read surface for the existing cold outbox:

- Add a bounded `pendingMutationProjectionOutboxRows(limit:)` read helper on `EventStore`.
- Return rows ordered by SQLite outbox `id` / insertion order so future projectors can consume deterministically.
- Clamp the caller-provided limit to a small maximum and return no rows for non-positive limits.
- Do not mark rows processed, add retry state, delete rows, emit events, call Rust, or wire UI.

Core/Pro/Both: Core/MAS-safe substrate.

## D. Alternatives

- Defer: safe, but future projector work would be tempted to query SQLite ad hoc.
- Add processed/attempt columns now: rejected as a broader schema and lifecycle change.
- Build a projector loop now: rejected because it would imply AgentEvent/GraphEvent semantics without a separate gate.
- Bridge directly to Rust `oplog`: rejected because Rust provenance files are dirty/high-risk and require their own deliberation.

## E. Reversal Triggers

- The helper needs any Rust, graph, editor, project, entitlement, or protected-path edit.
- The helper mutates outbox rows or creates a processing lifecycle.
- Tests expose nondeterministic ordering or unbounded reads.
- Focused EventStore/TextCapture/MutationEnvelope tests regress.

## F. Patch Plan

Files:

- `Epistemos/State/EventStore.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `EpistemosTests/TextCapturePipelineTests.swift`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

Protected files:

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- graph physics/render internals
- `agent_core` and `graph-engine`

Tests:

- Add a failing test proving pending outbox reads return committed rows in insertion order.
- Add limit coverage for zero, negative, and bounded positive limits.
- Preserve pending-envelope no-outbox behavior.
- Run:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/CognitiveSubstrateTests/EventStoreSchemaTests -only-testing:EpistemosTests/TextCapturePipelineTests -only-testing:EpistemosTests/MutationEnvelopeParityTests test`

Rollback:

- Revert `EventStore.swift`, focused tests, and this deliberation/results doc update.

Stop triggers:

- Any need to touch Rust, graph-engine, protected note editor, protected graph renderer, project files, entitlements, generated files, stashes, branches, staging, or commits.
- Any claim that this completes RunEventLog, AgentEvent, GraphEvent, Halo, or graph projection.

## G. Result

Status: **passed focused verification**.

Implemented:

- `EventStore.pendingMutationProjectionOutboxRows(limit:)` returns a bounded, read-only view of cold projection rows.
- Reads are deterministic by outbox insertion order (`id ASC`).
- Non-positive limits return no rows; positive limits are clamped to the internal maximum.
- The method has no side effects and does not mark rows processed, delete rows, add retry state, emit events, call Rust, or claim RunEventLog/AgentEvent/GraphEvent completion.
- Shared outbox row decoding avoids duplicating SQLite column mapping across the mutation-specific audit reader and the pending reader.

Verification:

- Red log: `/tmp/epistemos-outbox-pending-reader-red-20260430.log`
  - Expected compile failure: `Value of type 'EventStore' has no member 'pendingMutationProjectionOutboxRows'`.
- Schema green log: `/tmp/epistemos-outbox-pending-reader-schema-20260430.log`
  - `EventStore Cognitive Tables`: `9` tests passed.
  - Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_19-53-15--0500.xcresult`
- Final focused green log: `/tmp/epistemos-outbox-pending-reader-final-20260430.log`
  - `EventStore Cognitive Tables`: `9` tests passed.
  - `MutationEnvelope cross-language parity (T+4.8)`: `13` tests passed.
  - `TextCapturePipeline`: `37` tests passed.
  - `59` tests in `3` suites passed.
  - Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_19-59-11--0500.xcresult`

Guardrails:

- `git diff --check` passed for touched EventStore/test/deliberation files.
- Protected editor/graph diff audit remained empty.
- No Rust, graph-engine, protected note editor, protected graph renderer, project, entitlement, generated-file, stash, branch, staging, or commit action was taken.
- Xcode still reported SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains existing plugin/lint debt and not a compile/test blocker.
