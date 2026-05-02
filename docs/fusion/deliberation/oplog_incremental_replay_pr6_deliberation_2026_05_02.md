# OpLog Incremental Replay PR6 Deliberation - 2026-05-02

## Classification

Tier: Core
Slice: `oplog-incremental-replay-pr6`
Workcard: Card 6 - EventStore To OpLog Projection Gate

## Decision

Approve a narrow Swift-only/read-only incremental replay slice over the existing OpLog replay snapshot semantics.

## Why Now

- Current state says incremental replay remains open after PR5.
- Card 6 explicitly names incremental replay as a future replay target after PR4A/PR5.
- Current code already has the full replay fold and PR5 bundle export; PR6 can reduce future replay cost without altering authority, persistence, or UI.

## Allowed Files

- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/CognitiveSubstrateTests.swift`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/oplog_incremental_replay_pr6_deliberation_2026_05_02.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/oplog-incremental-replay-pr6/**`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/oversight/PREFLIGHT_14_2026_05_02.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/REGISTRY.md`
- Completion evidence in `/Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`, `/Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`, and `/Users/jojo/Downloads/Epistemos/docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`.

## Forbidden Files

- `/Users/jojo/Downloads/Epistemos/Epistemos/State/EventStore.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/RustOpLogFFIClient.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogProjector.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogProjectionWorker.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/**`
- `/Users/jojo/Downloads/Epistemos/agent_core/**`
- `/Users/jojo/Downloads/Epistemos/graph-engine/**`
- `/Users/jojo/Downloads/Epistemos/epistemos-shadow/**`
- Generated bindings, generated libraries, Xcode project files, entitlements, DerivedData, `.xcresult`.

## Implementation Shape

- Add a pure Swift incremental fold API to `MutationOpLogReplay`.
- Preserve existing full replay semantics: sort by `seq` then `lamport`, apply optional cutoff, count non-projection entries, keep the first projection per `mutationID`, and record later projections as duplicates.
- Preserve the prior snapshot's records, duplicates, ignored count, cutoff, and highest replayed sequence.
- Drop incoming entries with `seq <= snapshot.highestReplayedSeq` before the projection/non-projection branch; these overlap rows must never mutate ignored count, duplicates, records, or highest sequence.
- Seed duplicate detection from `snapshot.records` so a tail entry with an existing `mutationID` becomes a duplicate with `firstSeq` from the prior record.
- Cutoff rule: `upToSeq` wins when provided, otherwise preserve `snapshot.cutoffSeq`; lowering below an existing prior cutoff is unsupported by PR6.
- Add a bridge convenience only in `MutationOpLogReplay.swift`. If the prior snapshot has no `highestReplayedSeq`, bootstrap with existing `iterateAll()`; otherwise call existing `RustOpLogFFIClient.iterate(after:)`.
- Treat `MutationOpLogReplayBundle.replayedEntryCount` as cumulative for the merged snapshot, not tail-only; PR6 ships no tail-only bundle field.
- Do not export raw `sourcePayloadJSON` or add any new bundle shape.

## Tests

- Red test first: `Mutation OpLog incremental replay matches full replay`.
- The red equivalence test must split a corpus of at least six entries across two boundaries, include a duplicate split across the boundary, include one non-projection on each side, include unicode ids, and assert records, duplicates, ignored count, cutoff, and highest sequence equal full replay.
- Empty tail preserves the snapshot.
- Projection tail advances `highestReplayedSeq` and appends the new record.
- Duplicate tail appends a duplicate with the original first sequence.
- Non-projection tail increments ignored count.
- Replay tail at or below prior highest sequence is dropped before counting and does not double-count ignored rows, records, or duplicates.
- Same-seq higher-lamport tail entries are dropped under the OpLog sequence uniqueness invariant.
- Unicode mutation/artifact ids round-trip through incremental replay.
- Incremental snapshots exported through `MutationOpLogReplayBundle` still omit private source payload strings.
- Bridge convenience bootstraps an empty snapshot with `iterateAll()` and otherwise reads only entries after the prior snapshot's highest sequence.

## Acceptance

- Focused OpLog Swift Bridge tests pass.
- Incremental snapshot equals a full replay snapshot for the same complete entry set.
- Incremental-to-bundle export remains privacy-safe and deterministic.
- No EventStore, Rust ABI, UI, graph, generated binding, or scheduler files are staged.
- Production `MutationOpLogReplay.swift` contains no append/projector/dead-letter mutating symbols.
- PR6 docs and registry name the exact green log.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §8
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` OpLog PR5/current open lane
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 6

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 6 - EventStore To OpLog Projection Gate
- Deviation: This is a named future sub-gate under Card 6: incremental replay only. It narrows the write set below Card 6 because no EventStore, Rust ABI, projection worker, or UI changes are needed.

## Failure-proof guardrails (post-merge)

- grep: `applyIncremental`
- grep: `incrementalReplayMutationProjections`
- forbidden grep: `oplog_append_payload_json|markMutationProjectionOutboxProjected|recordMutationProjectionOutboxFailure|claimMutationProjectionOutboxRows`
- log: `✔ Test "Mutation OpLog incremental replay matches full replay" passed`
- test: `OpLog Swift Bridge`

## Fleet evidence packet

- `docs/fusion/fleet/oplog-incremental-replay-pr6/aggregator.md`
- `docs/fusion/fleet/oplog-incremental-replay-pr6/claude-side-fleet/aggregator.md`
- `docs/fusion/fleet/oplog-incremental-replay-pr6/claude-red-team/attacks.md` (pending)

## Usefulness

usefulness: +1
usefulness_reason: Authorizes a concrete pure-Swift incremental replay implementation and blocks all broader provenance/repair/UI work.
