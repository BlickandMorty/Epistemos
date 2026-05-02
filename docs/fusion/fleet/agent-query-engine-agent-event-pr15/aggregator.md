---
role: aggregator
source_fleet: codex-own
slice: agent-query-engine-agent-event-pr15
date: 2026-05-02
detectives_consumed:
  - detectives/agent-event-provenance.md
  - detectives/agent-query-engine.md
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
usefulness_reason: Converts the clean AgentQueryEngine backend stream seam into a bounded AgentEvent PR15.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` names AgentEvent as part of the substrate spine.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §14` covers multi-agent/ACS orchestration and supports provider-agnostic harness provenance.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 allows future runtime instrumentation only after a new gate names exact files and tests.
- `AgentQueryEngine.swift:222` and `AgentQueryEngine.swift:225` are the exact stream event seam to instrument.
- The GraphEvent scout found no safe GraphEvent code slice; PR15 should stay on AgentEvent only.

## Recommended slice shape
Approve a Core additive AgentEvent instrumentation slice for `AgentQueryEngine` backend tool-stream events only. Add an injectable `AgentToolProvenanceRecorder`, emit requested/started on backend `.toolUse`, and emit completed/failed on backend `.toolResult`. Persist only backend id, model id, turn index, tool call id/name, output byte count, error flag, source/surface metadata, and duration. Do not persist prompt, history, system prompt, cwd, backend logs, text/thinking deltas, tool input bytes, or tool output text.

## Failure-proof guardrails
- grep: `toolName: name`
- grep: `agentQueryEngineToolArgumentsJSON`
- forbidden grep: `argumentsJSON.*prompt|argumentsJSON.*history|argumentsJSON.*cwd|resultJSON.*output|resultJSON.*text|toolInput`
- log: `✔ Test "AgentQueryEngine records sanitized backend tool AgentEvents" passed`
- test: `AgentQueryEngine AgentEvent provenance`
