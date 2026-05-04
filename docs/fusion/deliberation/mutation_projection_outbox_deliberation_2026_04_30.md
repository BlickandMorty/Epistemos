# Deliberation Brief - Mutation Projection Outbox

Date: 2026-04-30
Owner: Codex overseer
Status: Approved for narrow implementation

## A. Repo Evidence

- `TextCapturePipeline` now returns a committed `MutationEnvelope` for persisted Quick Capture notes.
- `EventStore.saveMutationEnvelope(_:traceId:)` stores that envelope durably in `mutation_envelopes`.
- `MASTER_FUSION.md` defines the commit order as: commit RunEvent + MutationEnvelope, enqueue projection work into `projection_outbox`, then derive/publish AgentEvent + GraphEvent only after commit.
- No Swift `AgentEvent` projection bus exists yet; claiming full UI projection would be dishonest.
- The full Swift floor is green after the source-mirror repair: `/tmp/epistemos-full-after-contextual-source-mirror-20260430.log`, `5027` tests in `563` suites passed.

## B. Research Evidence

- `docs/_consolidated/00_canonical_authority/MASTER_FUSION.md` §3.5: `MutationEnvelope` records what changed; `AgentEvent` and `GraphEvent` are post-commit projections.
- `docs/_consolidated/00_canonical_authority/01_DOCTRINE.md` §2.1: a committed `MutationEnvelope` must not be silent, but hot events and cold envelopes remain different planes.
- `docs/RRF_FUSION_DESIGN.md` §9 item 3 explicitly defers retrieval `SourceOp` because that is a Rust/Swift wire-format parity change.
- Terminal Kimi advisory reviewed this slice as safe if it remains same-transaction, additive, no-tools/no-UI, and avoids `MutationEnvelope` schema changes.

## C. Decision

Implement a Swift-only projection outbox bridge:

- Add `mutation_projection_outbox` to `EventStore`.
- When `saveMutationEnvelope` saves a committed envelope, insert one projection-outbox row for that mutation in the same SQLite transaction.
- Keep the outbox additive and idempotent with `mutation_id UNIQUE`.
- Store a small sorted JSON payload with mutation id, trace id, status, artifact id, artifact kind, and integrity hash.
- Do not emit UI events, notifications, graph pulses, or new `SourceOp` variants in this slice.

Core/Pro/Both: Core/MAS-safe substrate.

## D. Alternatives

- Do nothing/defer: safe but leaves committed capture envelopes without a durable projection queue.
- Insert only into the existing `events` table: rejected for this slice because that table requires a session id and would imply a stronger AgentEvent surface than the code currently has.
- Add retrieval `SourceOp`: rejected because `docs/RRF_FUSION_DESIGN.md` defers that Rust/Swift parity change to T+13.
- Build full AgentEvent/GraphEvent UI projection: rejected as too broad and manual-verification dependent.

## E. Reversal Triggers

- Saving an envelope cannot be made transactional without destabilizing existing EventStore tests.
- The outbox row requires changes to `MutationEnvelope` or Rust parity files.
- Any existing event consumer mistakes the outbox for a visible UI event.
- Focused EventStore/TextCapture/MutationEnvelope tests fail outside this change.

## F. Patch Plan

Files:

- `Epistemos/State/EventStore.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift` and/or `EpistemosTests/TextCapturePipelineTests.swift`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

Protected files:

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- graph physics/render internals
- `agent_core` and `graph-engine`

Tests:

- Add a failing test proving a committed envelope creates exactly one projection-outbox row.
- Add idempotency coverage for repeated saves of the same committed envelope.
- Add a pending-envelope guard if practical.
- Run:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/CognitiveSubstrateTests/EventStoreSchemaTests -only-testing:EpistemosTests/TextCapturePipelineTests -only-testing:EpistemosTests/MutationEnvelopeParityTests test`

Rollback:

- Revert `EventStore.swift`, the focused tests, and this deliberation/results doc update.

Stop triggers:

- Any need to touch Rust, graph, editor, project, entitlements, stashes, branches, or generated files.
- Any non-additive EventStore schema change.
- Any claim that this completes the full AgentEvent/GraphEvent UI projection.

## G. Result

Status: **passed focused verification**.

Implemented:

- `EventStore` now creates `mutation_projection_outbox`.
- Committed envelopes enqueue exactly one projection row in the same SQLite transaction as the envelope upsert.
- Pending envelopes persist without entering the outbox.
- The outbox payload is sorted JSON and remains a cold projection queue, not a visible UI event bus.

Verification:

- `/tmp/epistemos-mutation-projection-outbox-20260430.log`
  - `MutationEnvelope cross-language parity (T+4.8)`: `13` tests passed.
  - `TextCapturePipeline`: `37` tests passed.
  - `** TEST SUCCEEDED **`
- `/tmp/epistemos-mutation-projection-outbox-schema-20260430.log`
  - `EventStore Cognitive Tables`: `8` tests passed.
  - `** TEST SUCCEEDED **`

Guardrails:

- `git diff --check` passed for the touched EventStore/test/deliberation/results files.
- Protected editor/graph diff audit remained empty.
- No Rust, graph-engine, protected note editor, protected graph renderer, project, entitlement, generated-file, stash, branch, staging, or commit action was taken.
