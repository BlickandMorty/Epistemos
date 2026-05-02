---
role: claude-red-team
slice: oplog-incremental-replay-pr6
brief: docs/fusion/deliberation/oplog_incremental_replay_pr6_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 8
p0_attacks: 1
p1_attacks: 4
p2_attacks: 2
p3_attacks: 1
verdict: brief-revise
usefulness: +1
usefulness_reason: PR6 is correctly scoped as Swift-only, but boundary semantics and privacy regression tests must be pinned before code lands.
---

## Attacks

### A1 - Ambiguous ignored-count accounting across the snapshot boundary [P0]
**Surface:** Implementation Shape.
**Attack:** The brief said to preserve prior ignored count and skip already-replayed rows, but did not say whether overlapping non-projection entries mutate ignored count. That could break the headline incremental/full equivalence.
**Evidence:** `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:139`.
**Mitigation proposed:** Pin that entries with `seq <= snapshot.highestReplayedSeq` are dropped before projection/non-projection handling and never mutate ignored count, duplicates, or records.

### A2 - Empty bridge snapshot cannot use `iterate(after: 0)` [P1]
**Surface:** Bridge convenience.
**Attack:** The first OpLog row can be `seq == 0`, so an empty snapshot cannot bootstrap by calling `iterate(after: 0)` because that drops the first row.
**Evidence:** `/Users/jojo/Downloads/Epistemos/EpistemosTests/CognitiveSubstrateTests.swift:2740`.
**Mitigation proposed:** Allow the bridge helper to use `iterateAll()` only when the prior snapshot has no `highestReplayedSeq`; otherwise use `iterate(after:)`.

### A3 - Privacy guard must cover incremental snapshots exported via PR5 bundle [P1]
**Surface:** Privacy/export boundary.
**Attack:** Incremental replay preserves `sourcePayloadJSON` in internal records; PR6 must prove PR5 bundle export still strips private payloads when the snapshot came from incremental replay.
**Evidence:** `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:14`.
**Mitigation proposed:** Add an incremental-to-bundle test with private body/cwd/system prompt strings and assert deterministic JSON omits all private substrings.

### A4 - Cross-boundary duplicate detection must seed from prior records [P1]
**Surface:** Duplicate semantics.
**Attack:** A tail projection with an existing `mutationID` must become a duplicate rather than a second record, or `recordsByMutationID` can crash on duplicate keys.
**Evidence:** `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:30`.
**Mitigation proposed:** Seed the duplicate-detection map from `snapshot.records` before processing tail entries and test the duplicate split across the boundary.

### A5 - Cutoff semantics are undefined when caller passes a new cutoff [P1]
**Surface:** Incremental API signature.
**Attack:** Preserving prior cutoff while accepting a new `upToSeq` creates ambiguous returned `cutoffSeq` behavior.
**Evidence:** `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:140`.
**Mitigation proposed:** Pin that `upToSeq` wins when provided, otherwise prior cutoff is preserved; lowering below a prior cutoff is not supported by PR6.

### A6 - Same-seq lamport boundary should be explicit [P2]
**Surface:** Cursor skip rule.
**Attack:** `replay()` sorts by `(seq, lamport)`, but incremental skip by `seq <= highestReplayedSeq` assumes unique OpLog seq values.
**Evidence:** `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:126`.
**Mitigation proposed:** Add a source comment/test that same-seq higher-lamport tail entries are dropped under the OpLog sequence uniqueness invariant.

### A7 - Bundle `replayedEntryCount` is cumulative, not tail-only [P2]
**Surface:** ReplayBundle semantics.
**Attack:** Bundles wrapping incremental snapshots report cumulative snapshot counts, not entries processed by the incremental call.
**Evidence:** `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:104`.
**Mitigation proposed:** Document that PR6 ships no tail-only bundle field; downstream observability needs a future Card 6 gate.

### A8 - Red-test construction must be strong enough [P3]
**Surface:** Test plan.
**Attack:** A weak two-entry split could miss ignored-count, duplicate-boundary, and cutoff bugs.
**Evidence:** `docs/fusion/deliberation/oplog_incremental_replay_pr6_deliberation_2026_05_02.md`.
**Mitigation proposed:** Require a multi-entry corpus split across boundaries with duplicate and non-projection entries on both sides, then assert full snapshot equality.

## Brief verdict

Brief must be revised before code. Scope and file boundaries are sound, but the P0/P1 semantic contracts need to be pinned in the brief and tests before implementation.

CLAUDE-RETURN: role=RED-TEAM | slice=oplog-incremental-replay-pr6 | round=14 | artifact=stdout | usefulness=+1 | p0=1 | p1=4
