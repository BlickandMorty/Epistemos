---
role: detective
slice: oplog-incremental-replay-pr6
concept: Replay boundary and privacy
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §8
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/oplog-replay-bundle-export-pr5/claude-red-team/attacks.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:202
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/CognitiveSubstrateTests.swift:2829
deliberations_consulted:
  - docs/fusion/deliberation/oplog_replay_bundle_export_pr5_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted: []
drift:
  detected: false
  canon_says: "Do not export raw `sourcePayloadJSON`"
  code_says: "[paraphrase] Bundle records omit sourcePayloadJSON; replay records still keep it internally."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift
load_bearing_quote: "Do not export raw `sourcePayloadJSON`"
verdict: open
usefulness: +1
usefulness_reason: Keeps PR6 from widening PR5 export/privacy scope while adding replay mechanics.
---

## Findings

- PR5 red-team already flagged source-payload privacy as the main ReplayBundle boundary in `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/oplog-replay-bundle-export-pr5/claude-red-team/attacks.md:18`.
- Card 6 now states PR5 already supplies deterministic read-only bundle export and forbids raw source payload export in `/Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md:578`.
- Current `MutationOpLogReplayRecord` still keeps `sourcePayloadJSON` internally at `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:14`; PR6 should not create any new exported shape from that field.
- Current bridge convenience methods live in the replay file extension at `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:202`, so PR6 can add a read-only bridge convenience there without editing `RustOpLogFFIClient.swift`.

## Open questions

- Should bridge incremental replay accept a prior snapshot and call `iterate(after:)`, or should PR6 stay snapshot-only and leave bridge convenience for a later production visibility gate?

## Recommendation

Keep PR6 snapshot-first: add deterministic incremental fold semantics and tests first. Only add a bridge convenience if it can call existing `iterate(after:)` with no raw ABI changes and no UI/production scheduling behavior.
