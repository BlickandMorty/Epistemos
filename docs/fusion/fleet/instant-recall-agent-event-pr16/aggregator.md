---
role: aggregator
source_fleet: codex-own
slice: instant-recall-agent-event-pr16
date: 2026-05-02
detectives_consumed:
  - detectives/agent-event-provenance.md
  - detectives/instant-recall.md
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
usefulness_reason: Converts the canonical InstantRecall sync search seam into a bounded AgentEvent PR16.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` names AgentEvent as substrate-spine provenance rather than UI-only diagnostics.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §5` names InstantRecall as the Swift recall fallback for Halo / Contextual Shadows.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 allows future runtime AgentEvent emission only after an exact-file gate.
- `InstantRecallService.swift:189` is the approved sync-search seam; `InstantRecallService.swift:477` remains out of scope.

## Recommended slice shape
Approve a Core additive AgentEvent instrumentation slice for `InstantRecallService.search(queryText:topK:)` only. Add an injectable `AgentToolProvenanceRecorder`, emit requested/started before the Rust search, emit completed/failed after decode, and persist only query character count, query term count, topK, hit count, document count, elapsed milliseconds, source/surface metadata, and failure class. Do not persist query text, note ids, note bodies, result text, snippets, vault paths, source text, async recall events, Halo events, ShadowSearch payloads, editor state, or graph state.

## Failure-proof guardrails
- grep: `toolName: "instant_recall.search"`
- grep: `instantRecallSearchArgumentsJSON`
- forbidden grep: `argumentsJSON.*query|argumentsJSON.*text|argumentsJSON.*doc|resultJSON.*query|resultJSON.*text|resultJSON.*doc|resultJSON.*body`
- log: `✔ Test "Search records sanitized AgentEvents" passed`
- test: `InstantRecall — Service`
