# GraphEvent Projection Consumer PR4 Deliberation - 2026-05-02

## Claim

Durable GraphEvent PR3 can fold provided rows into a deterministic snapshot,
and EventStore can return recent graph-event rows, but consumers still have to
manually compose those two operations. This slice adds one bounded, read-only
EventStore consumer API for recent GraphEvent projection snapshots.

## Approved Write Set

- `Epistemos/State/EventStore.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- this deliberation file

## Forbidden

- No `Epistemos/Views/Graph/**`, `Epistemos/Graph/**`, graph renderer, Rust,
  FFI, generated binding, OpLog worker, retrieval, Halo, Theater, Omega, or
  protected editor edits.
- No mutation, repair, polling, UI, or live renderer side effects.
- No `MutationEnvelope` wire-format changes.

## Test Gate

Add a failing focused EventStore test requiring
`graphEventProjectionSnapshot(limit:)` to:

- read recent durable GraphEvent rows in existing chronological projection
  order;
- fold them through `DurableGraphEventProjection.snapshot(from:)`;
- return an empty snapshot for `limit <= 0`;
- remain read-only and bounded.

Then implement only the minimal EventStore method and run the focused
CognitiveSubstrate test suite plus source/protected-path audits.

## Result

- Red confirmed in
  `/tmp/epistemos-graph-event-projection-consumer-pr4-red-20260502.log`: the
  test failed because `EventStore` had no
  `graphEventProjectionSnapshot(limit:)`.
- Green accepted in
  `/tmp/epistemos-graph-event-projection-consumer-pr4-green-r2-20260502.log`:
  `EventStoreSchemaTests` executed 34 Swift Testing tests, including the new
  projection-consumer test, and passed.
- The first green command targeted the filename and selected 0 tests; it is not
  acceptance evidence.
- Known Xcode package-plugin noise still appears after `TEST SUCCEEDED` for
  SwiftLint on CodeEdit packages; it did not fail the selected test run.
