---
role: detective
slice: oplog-incremental-replay-pr6
concept: OpLog incremental replay
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §8
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/oplog_replay_bundle_export_pr5_deliberation_2026_05_02.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:121
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/CognitiveSubstrateTests.swift:2788
deliberations_consulted:
  - docs/fusion/deliberation/oplog_replay_bundle_export_pr5_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted: []
drift:
  detected: false
  canon_says: "Incremental replay, production visibility, and mutating rollback/repair"
  code_says: "[paraphrase] Current replay folds a full sorted entry array into a fresh snapshot."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift
load_bearing_quote: "Incremental replay, production visibility, and mutating rollback/repair"
verdict: open
usefulness: +1
usefulness_reason: Establishes PR6 as an explicitly open Card 6 replay sub-gate.
---

## Findings

- Current code builds a replay snapshot from a sorted full entry list in `MutationOpLogReplay.replay(...)` at `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:121`.
- Current replay semantics dedupe by `mutationID` and record duplicate projections at `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:150`.
- Current tests cover full replay, cutoff rollback inspection, duplicate detection, ReplayBundle JSON, and real OpLog bridge export in `/Users/jojo/Downloads/Epistemos/EpistemosTests/CognitiveSubstrateTests.swift:2788`.
- PR6 can be additive if it derives a new snapshot by replaying existing snapshot state plus new entries without touching EventStore, Rust ABI, UI, generated bindings, or scheduling.

## Open questions

- Should the incremental API reject or ignore entries at or below `highestReplayedSeq`?
- Should incremental replay preserve the original `cutoffSeq` or require an explicit cutoff argument on each incremental call?

## Recommendation

Implement a pure Swift incremental replay helper that appends new OpLog entries to an existing `MutationOpLogReplaySnapshot`, preserves existing records/duplicates/ignored counts, and produces the same result as full replay for ordered tails, duplicate tails, non-projection tails, empty tails, unicode ids, and cutoff-bounded tails.
