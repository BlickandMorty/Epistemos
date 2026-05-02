---
role: aggregator
source_fleet: codex-own
slice: agent-grep-agent-event-pr14
date: 2026-05-02
detectives_consumed:
  - detectives/agent-event-provenance.md
  - detectives/agent-grep-search.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts: []
drift_signals: []
tier: Core
sovereign_gate_touchpoint: none
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: false
  freeform_pulse: false
  residency_rail: false
  unclosed_core_blocker: none
ready_for_pipeline_builder: true
missing_artifacts: []
input_usefulness_rollup:
  plus_one: 2
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Turns the clean AgentGrep search surface into the next bounded AgentEvent PR.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` names AgentEvent as part of the substrate spine.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:698` leaves broader runtime AgentEvent coverage open after PR13.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:800` allows future runtime instrumentation after a new exact gate names files and focused tests.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:905` requires a failing test first for future live-emission PRs.
- `AgentGrepService.swift:160` is the clean single search chokepoint; `AgentGrepServiceTests.swift:143` and `AgentGrepServiceTests.swift:198` close the success/failure privacy contract.

## Recommended slice shape
Approve a Core additive AgentEvent instrumentation slice for `AgentGrepService.search(...)` only. Emit requested/started/completed/failed events with `agent-grep-...` run ids and `agent-grep-search:1` tool call identity. Persist only kind filter, limit, hit count, source/surface, and backend failure class. Do not persist query text, file paths, snippets, file bodies, source text, sidecar provenance ids, or tool-use ids.

## Failure-proof guardrails
- grep: `toolName: "agent_grep.search"`
- grep: `agentGrepSearchArgumentsJSON`
- forbidden grep: `argumentsJSON.*query|resultJSON.*snippet|resultJSON.*vaultRelativePath|resultJSON.*provenance`
- log: `✔ Test "search records sanitized AgentEvents" passed`
- test: `AgentGrepService (Wave 9.9 base)`
