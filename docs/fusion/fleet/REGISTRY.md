# Epistemos Fleet Live Agent Registry - current month

This registry tracks Codex-spawned research, web, aggregation, pipeline-builder,
Claude side-fleet, Claude red-team, Kimi, and other long-running agent/process
dispatches. Update it before and after every spawn. Never delete rows; archive
old rows monthly to `docs/fusion/fleet/REGISTRY_ARCHIVE_<YYYY-MM>.md`.

Current status on 2026-05-02: round 14 OpLog incremental replay PR6 completed as a Swift-only/read-only provenance slice; next safe slice selection pending.

| round | spawned_at | role | scope | tool_surface | terminal_or_pid | status | artifact | usefulness |
|---|---|---|---|---|---|---|---|---|
| 3 | 2026-05-02T17:00Z | detective | concept=Sovereign Gate destructive confirmation | codex/local | n/a | done | docs/fusion/fleet/sovereign-gate-version-delete-pr7/detectives/sovereign-gate.md | +1 |
| 3 | 2026-05-02T17:00Z | detective | concept=DiffSheet version delete | codex/local | n/a | done | docs/fusion/fleet/sovereign-gate-version-delete-pr7/detectives/diffsheet-version-delete.md | +1 |
| 3 | 2026-05-02T17:00Z | aggregator | slice=sovereign-gate-version-delete-pr7 | codex/local | n/a | done | docs/fusion/fleet/sovereign-gate-version-delete-pr7/aggregator.md | +1 |
| 3 | 2026-05-02T17:00Z | pipeline-builder | slice=sovereign-gate-version-delete-pr7 | codex/local | n/a | done | docs/fusion/deliberation/sovereign_gate_version_delete_pr7_deliberation_2026_05_02.md | +1 |
| 3 | 2026-05-02T17:00Z | claude-red-team | brief=sovereign-gate-version-delete-pr7 | codex/explorer-agent | agent:019de9a3-829c-7c00-ae46-3a0e891bd878 | done | docs/fusion/fleet/sovereign-gate-version-delete-pr7/claude-red-team/attacks.md | +1 |
| 4 | 2026-05-02T17:27Z | explorer | scope=next-slice-ranking | codex/explorer-agent | agent:019de9ba-fde0-7600-8adc-745617f93f2e | done | transcript | +1 |
| 4 | 2026-05-02T17:27Z | explorer | scope=graph-event-pr8-audit | codex/explorer-agent | agent:019de9ba-fe3c-7a00-96da-4e181186d7ec | done | transcript | +1 |
| 5 | 2026-05-02T17:37Z | detective | concept=Sovereign Gate destructive confirmation | codex/local | n/a | done | docs/fusion/fleet/sovereign-gate-rootview-destructive-pr8/detectives/sovereign-gate.md | +1 |
| 5 | 2026-05-02T17:37Z | detective | concept=RootView destructive controls | codex/local | n/a | done | docs/fusion/fleet/sovereign-gate-rootview-destructive-pr8/detectives/rootview-destructive-controls.md | +1 |
| 5 | 2026-05-02T17:38Z | aggregator | slice=sovereign-gate-rootview-destructive-pr8 | codex/local | n/a | done | docs/fusion/fleet/sovereign-gate-rootview-destructive-pr8/aggregator.md | +1 |
| 5 | 2026-05-02T17:38Z | pipeline-builder | slice=sovereign-gate-rootview-destructive-pr8 | codex/local | n/a | done | docs/fusion/deliberation/sovereign_gate_rootview_destructive_pr8_deliberation_2026_05_02.md | +1 |
| 5 | 2026-05-02T17:37Z | claude-red-team | brief=sovereign-gate-rootview-destructive-pr8 | codex/explorer-agent | agent:019de9c4-5e54-7560-b463-66acb6e59c46 | done | docs/fusion/fleet/sovereign-gate-rootview-destructive-pr8/claude-red-team/attacks.md | +1 |
| 7 | 2026-05-02T18:05Z | detective | concept=GraphEvent audit projection | codex/local | n/a | done | docs/fusion/fleet/graph-event-audit-visibility-pr8/detectives/graph-event-audit-projection.md | +1 |
| 7 | 2026-05-02T18:05Z | detective | concept=Settings GraphEvent visibility row | codex/local | n/a | done | docs/fusion/fleet/graph-event-audit-visibility-pr8/detectives/settings-visibility-row.md | +1 |
| 7 | 2026-05-02T18:05Z | aggregator | slice=graph-event-audit-visibility-pr8 | codex/local | n/a | done | docs/fusion/fleet/graph-event-audit-visibility-pr8/aggregator.md | +1 |
| 7 | 2026-05-02T18:05Z | pipeline-builder | slice=graph-event-audit-visibility-pr8 | codex/local | n/a | done | docs/fusion/deliberation/graph_event_audit_visibility_pr8_deliberation_2026_05_02.md | +1 |
| 7 | 2026-05-02T18:05Z | claude-red-team | brief=graph-event-audit-visibility-pr8 | codex/explorer-agent | agent:019de9dd-fe7b-7873-91de-e3ab8051dc8b | done | docs/fusion/fleet/graph-event-audit-visibility-pr8/claude-red-team/attacks.md | +1 |
| 8 | 2026-05-02T18:19Z | explorer | scope=agent-event-next-slice-scout | codex/explorer-agent | agent:019de9ea-54a4-7253-b005-baaed784f573 | done | transcript | +1 |
| 8 | 2026-05-02T18:19Z | explorer | scope=graph-event-next-slice-scout | codex/explorer-agent | agent:019de9ea-5508-73a2-af55-11ce1d3028f0 | done | transcript | +1 |
| 9 | 2026-05-02T18:29Z | detective | concept=AgentEvent provenance hardening | codex/local | n/a | done | docs/fusion/fleet/agent-grep-agent-event-pr14/detectives/agent-event-provenance.md | +1 |
| 9 | 2026-05-02T18:29Z | detective | concept=AgentGrep search lifecycle | codex/local | n/a | done | docs/fusion/fleet/agent-grep-agent-event-pr14/detectives/agent-grep-search.md | +1 |
| 9 | 2026-05-02T18:29Z | aggregator | slice=agent-grep-agent-event-pr14 | codex/local | n/a | done | docs/fusion/fleet/agent-grep-agent-event-pr14/aggregator.md | +1 |
| 9 | 2026-05-02T18:29Z | pipeline-builder | slice=agent-grep-agent-event-pr14 | codex/local | n/a | done | docs/fusion/deliberation/agent_grep_agent_event_pr14_deliberation_2026_05_02.md | +1 |
| 9 | 2026-05-02T18:31Z | claude-red-team | brief=agent-grep-agent-event-pr14 | codex/explorer-agent | agent:019de9f5-8e27-7ce2-8299-2803e40cc73c | done | docs/fusion/fleet/agent-grep-agent-event-pr14/claude-red-team/attacks.md | +1 |
| 10 | 2026-05-02T18:41Z | explorer | scope=agent-event-next-slice-scout | codex/explorer-agent | agent:019de9fe-d595-7970-b08b-ecbad8e97e3e | done | transcript | +1 |
| 10 | 2026-05-02T18:41Z | explorer | scope=graph-event-next-slice-scout | codex/explorer-agent | agent:019de9fe-d600-7752-a559-586cb10104a2 | done | transcript | +1 |
| 10 | 2026-05-02T18:46Z | detective | concept=AgentEvent provenance hardening | codex/local | n/a | done | docs/fusion/fleet/agent-query-engine-agent-event-pr15/detectives/agent-event-provenance.md | +1 |
| 10 | 2026-05-02T18:46Z | detective | concept=AgentQueryEngine backend stream | codex/local | n/a | done | docs/fusion/fleet/agent-query-engine-agent-event-pr15/detectives/agent-query-engine.md | +1 |
| 10 | 2026-05-02T18:46Z | aggregator | slice=agent-query-engine-agent-event-pr15 | codex/local | n/a | done | docs/fusion/fleet/agent-query-engine-agent-event-pr15/aggregator.md | +1 |
| 10 | 2026-05-02T18:46Z | pipeline-builder | slice=agent-query-engine-agent-event-pr15 | codex/local | n/a | done | docs/fusion/deliberation/agent_query_engine_agent_event_pr15_deliberation_2026_05_02.md | +1 |
| 10 | 2026-05-02T18:46Z | claude-red-team | brief=agent-query-engine-agent-event-pr15 | codex/local-red-team | n/a | done | docs/fusion/fleet/agent-query-engine-agent-event-pr15/claude-red-team/attacks.md | +1 |
| 11 | 2026-05-02T19:24Z | detective | concept=AgentEvent provenance hardening | codex/local | n/a | done | docs/fusion/fleet/instant-recall-agent-event-pr16/detectives/agent-event-provenance.md | +1 |
| 11 | 2026-05-02T19:24Z | detective | concept=InstantRecall sync recall search | codex/local | n/a | done | docs/fusion/fleet/instant-recall-agent-event-pr16/detectives/instant-recall.md | +1 |
| 11 | 2026-05-02T19:24Z | aggregator | slice=instant-recall-agent-event-pr16 | codex/local | n/a | done | docs/fusion/fleet/instant-recall-agent-event-pr16/aggregator.md | +1 |
| 11 | 2026-05-02T19:24Z | pipeline-builder | slice=instant-recall-agent-event-pr16 | codex/local | n/a | done | docs/fusion/deliberation/instant_recall_agent_event_pr16_deliberation_2026_05_02.md | +1 |
| 11 | 2026-05-02T19:24Z | claude-red-team | brief=instant-recall-agent-event-pr16 | codex/local-red-team | n/a | done | docs/fusion/fleet/instant-recall-agent-event-pr16/claude-red-team/attacks.md | +1 |
| 12 | 2026-05-02T19:31Z | explorer | scope=next-safe-slice-selection | codex/explorer-agent | agent:019dea2b-5353-79e0-9eb0-f3d98b377b11 | done | transcript | +1 |
| 13 | 2026-05-02T19:33Z | detective | concept=OpLog replay/export | codex/local | n/a | done | docs/fusion/fleet/oplog-replay-bundle-export-pr5/detectives/oplog-replay-export.md | +1 |
| 13 | 2026-05-02T19:33Z | detective | concept=ReplayBundle boundary | codex/local | n/a | done | docs/fusion/fleet/oplog-replay-bundle-export-pr5/detectives/replay-bundle-boundary.md | +1 |
| 13 | 2026-05-02T19:33Z | aggregator | slice=oplog-replay-bundle-export-pr5 | codex/local | n/a | done | docs/fusion/fleet/oplog-replay-bundle-export-pr5/aggregator.md | +1 |
| 13 | 2026-05-02T19:33Z | pipeline-builder | slice=oplog-replay-bundle-export-pr5 | codex/local | n/a | done | docs/fusion/deliberation/oplog_replay_bundle_export_pr5_deliberation_2026_05_02.md | +1 |
| 13 | 2026-05-02T19:34Z | claude-red-team | brief=oplog-replay-bundle-export-pr5 | codex/worker-agent | agent:019dea30-d5e1-7c10-a3f8-82364dee3f3e | done | docs/fusion/fleet/oplog-replay-bundle-export-pr5/claude-red-team/attacks.md | +1 |
| 14 | 2026-05-02T19:55Z | claude-side-fleet | scope=oplog-incremental-replay-pr6 | claude/print-readonly | session:65510 | failed | docs/fusion/fleet/oplog-incremental-replay-pr6/claude-side-fleet/aggregator.md | -1 |
| 14 | 2026-05-02T20:00Z | claude-side-fleet | scope=oplog-incremental-replay-pr6 | claude/print-readonly | pid:56732 | done | docs/fusion/fleet/oplog-incremental-replay-pr6/claude-side-fleet/aggregator.md | +1 |
| 14 | 2026-05-02T20:04Z | detective | concept=OpLog incremental replay | codex/local | n/a | done | docs/fusion/fleet/oplog-incremental-replay-pr6/detectives/oplog-incremental-replay.md | +1 |
| 14 | 2026-05-02T20:04Z | detective | concept=Replay boundary and privacy | codex/local | n/a | done | docs/fusion/fleet/oplog-incremental-replay-pr6/detectives/replay-boundary.md | +1 |
| 14 | 2026-05-02T20:04Z | aggregator | slice=oplog-incremental-replay-pr6 | codex/local | n/a | done | docs/fusion/fleet/oplog-incremental-replay-pr6/aggregator.md | +1 |
| 14 | 2026-05-02T20:04Z | pipeline-builder | slice=oplog-incremental-replay-pr6 | codex/local | n/a | done | docs/fusion/deliberation/oplog_incremental_replay_pr6_deliberation_2026_05_02.md | +1 |
| 14 | 2026-05-02T20:05Z | claude-red-team | brief=oplog-incremental-replay-pr6 | claude/print-readonly | pid:58283 | done | docs/fusion/fleet/oplog-incremental-replay-pr6/claude-red-team/attacks.md | +1 |
| 14 | 2026-05-02T20:14Z | implementation | slice=oplog-incremental-replay-pr6 | codex/local | n/a | done | Epistemos/Engine/MutationOpLogReplay.swift | +1 |
| 14 | 2026-05-02T20:14Z | test | suite=OpLogSwiftBridgeTests | xcodebuild | session:15383 | done | /tmp/epistemos-oplog-incremental-replay-pr6-green-20260502.log | +1 |
| 14 | 2026-05-02T20:14Z | guard | slice=oplog-incremental-replay-pr6 | codex/local | n/a | done | docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md | +1 |
| 15 | 2026-05-02T20:17Z | claude-side-fleet | scope=next-provenance-slice-selection | claude/print-readonly | session:70972 | done | docs/fusion/fleet/round-15-next-provenance-slice-selection/claude-side-fleet/aggregator.md | +1 |
| 16 | 2026-05-02T20:22Z | detective | concept=AgentEvent provenance hardening | codex/local | n/a | done | docs/fusion/fleet/instant-recall-async-agent-event-pr17/detectives/agent-event-provenance.md | +1 |
| 16 | 2026-05-02T20:22Z | detective | concept=InstantRecall async recall search | codex/local | n/a | done | docs/fusion/fleet/instant-recall-async-agent-event-pr17/detectives/instant-recall-async.md | +1 |
| 16 | 2026-05-02T20:22Z | aggregator | slice=instant-recall-async-agent-event-pr17 | codex/local | n/a | done | docs/fusion/fleet/instant-recall-async-agent-event-pr17/aggregator.md | +1 |
| 16 | 2026-05-02T20:22Z | pipeline-builder | slice=instant-recall-async-agent-event-pr17 | codex/local | n/a | done | docs/fusion/deliberation/instant_recall_async_agent_event_pr17_deliberation_2026_05_02.md | +1 |
| 16 | 2026-05-02T20:24Z | claude-red-team | brief=instant-recall-async-agent-event-pr17 | claude/print-readonly | session:86409 | done | docs/fusion/fleet/instant-recall-async-agent-event-pr17/claude-red-team/attacks.md | +1 |
| 16 | 2026-05-02T20:36Z | implementation | slice=instant-recall-async-agent-event-pr17 | codex/local | n/a | done | Epistemos/KnowledgeFusion/InstantRecallService.swift | +1 |
| 16 | 2026-05-02T20:36Z | test | suite=InstantRecallServiceTests | xcodebuild | session:44506 | done | /tmp/epistemos-instant-recall-async-agent-event-pr17-green-20260502.log | +1 |
| 16 | 2026-05-02T20:36Z | guard | slice=instant-recall-async-agent-event-pr17 | codex/local | n/a | done | docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md | +1 |
