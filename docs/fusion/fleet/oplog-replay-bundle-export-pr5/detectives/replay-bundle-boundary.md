---
role: detective
slice: oplog-replay-bundle-export-pr5
concept: ReplayBundle boundary
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §1
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/oplog_chain_verification_pr4b_deliberation_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:116
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/RustOpLogFFIClient.swift:88
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/CognitiveSubstrateTests.swift:2828
deliberations_consulted:
  - docs/fusion/deliberation/eventstore_oplog_replay_snapshot_pr4a_deliberation_2026_05_01.md
  - docs/fusion/deliberation/oplog_chain_verification_pr4b_deliberation_2026_05_01.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: false
  canon_says: "future replay work should target incremental replay, ReplayBundle export, or production visibility"
  code_says: "[paraphrase] replay convenience exists, bundle export does not."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift
load_bearing_quote: "future replay work should target incremental replay, ReplayBundle export, or production visibility"
verdict: open
usefulness: +1
usefulness_reason: Defines the safe boundary: extend the replay layer, do not rebuild projection or chain verification.
---

## Findings

- Card 6 names ReplayBundle export as a future gate at `/Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md:501`.
- Card 6 says not to rebuild PR4A's replay fold at `/Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md:566`.
- Card 6 says not to add repair, rollback execution, generated bindings, or second raw ABI bridge at `/Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md:570`.
- PR4A's deliberation forbids EventStore mutation, OpLog append, UI, scheduling, Rust ABI, and generated binding edits.

## Open questions

- None. The safe implementation target is an immutable export value plus deterministic JSON encoding.

## Recommendation

Keep the bundle API in `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift`, beside the existing replay snapshot. Use focused `OpLogSwiftBridgeTests` coverage and protected-path greps to prove the slice did not leak.
