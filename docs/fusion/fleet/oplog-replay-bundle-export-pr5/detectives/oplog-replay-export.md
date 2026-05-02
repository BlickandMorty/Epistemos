---
role: detective
slice: oplog-replay-bundle-export-pr5
concept: OpLog replay/export
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §1
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/eventstore_oplog_replay_snapshot_pr4a_deliberation_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:23
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:35
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/CognitiveSubstrateTests.swift:2787
deliberations_consulted:
  - docs/fusion/deliberation/eventstore_oplog_replay_snapshot_pr4a_deliberation_2026_05_01.md
  - docs/fusion/deliberation/oplog_chain_verification_pr4b_deliberation_2026_05_01.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: false
  canon_says: "Incremental replay, ReplayBundle export, and mutating rollback/repair semantics"
  code_says: "[paraphrase] MutationOpLogReplay already folds snapshots but has no ReplayBundle export."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift
load_bearing_quote: "Incremental replay, ReplayBundle export, and mutating rollback/repair semantics"
verdict: open
usefulness: +1
usefulness_reason: Confirms ReplayBundle export is an explicitly open provenance-hardening lane.
---

## Findings

- Current state leaves ReplayBundle export open at `/Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:648`.
- Existing Swift replay snapshots are already closed and read-only at `/Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:105`.
- The fold layer lives in `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:35` and already sorts by sequence/lamport.
- Focused replay tests live at `/Users/jojo/Downloads/Epistemos/EpistemosTests/CognitiveSubstrateTests.swift:2787`.

## Open questions

- None for this slice. Web validation is not required because this is pure local Swift data modeling over existing decoded OpLog entries.

## Recommendation

Add a deterministic `Codable` ReplayBundle over `MutationOpLogReplaySnapshot`, keeping it read-only and Swift-only. Do not add repair, rollback execution, UI, raw ABI, or EventStore mutation.
