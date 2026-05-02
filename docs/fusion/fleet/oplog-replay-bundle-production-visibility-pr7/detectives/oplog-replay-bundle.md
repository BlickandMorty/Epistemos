---
role: detective
slice: oplog-replay-bundle-production-visibility-pr7
concept: OpLog ReplayBundle visibility
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:35
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:290
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/OpLogProjectionHealthRow.swift:10
deliberations_consulted:
  - docs/fusion/deliberation/oplog_replay_bundle_export_pr5_deliberation_2026_05_02.md
  - docs/fusion/deliberation/oplog_incremental_replay_pr6_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted: []
drift:
  detected: false
  canon_says: "Read-only ReplayBundle export is already closed as PR5."
  code_says: "[paraphrase] MutationOpLogReplayBundle and exportMutationReplayBundle already exist."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift
load_bearing_quote: "production ReplayBundle visibility"
verdict: open
usefulness: +1
usefulness_reason: "Identifies an open Card 6 visibility gap downstream of closed replay/export code."
---

## Findings
- Card 6 explicitly leaves production ReplayBundle visibility open after PR5/PR6.
- Current code already has deterministic `MutationOpLogReplayBundle` JSON export and privacy tests.
- Settings already has an OpLog diagnostics row shape, but it only reports projection/dead-letter health today.

## Open questions
- Whether Settings may open the Rust OpLog read-only through a dedicated service. This slice avoids raw ABI in the view and keeps the report read-only.

## Recommendation
Add a small `MutationOpLogReplayBundleVisibilityReport` over the existing bundle and display its counts in `OpLogProjectionHealthRow` without repair actions, timers, or raw ABI symbols in the view.
