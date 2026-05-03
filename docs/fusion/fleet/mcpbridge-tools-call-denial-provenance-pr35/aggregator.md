---
role: aggregator
source_fleet: codex-own
slice: mcpbridge-tools-call-denial-provenance-pr35
date: 2026-05-03
detectives_consumed:
  - detectives/mcpbridge-tools-call-denial-provenance.md
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
  plus_one: 1
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Turns a closed Core MCP denial gate into auditable durable provenance without widening execution.
---

## Reconciled findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §6` is the canon anchor for MCP/omega-mcp; the current slice stays on the Swift policy gate and does not advance Rust MCP execution.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:1116` and `AGENT_BUILD_WORKCARDS_2026_05_01.md:2521` agree that Core `tools/call` denial is already shipped behavior.
- `Epistemos/Omega/MCPBridge.swift:309` is the exact chokepoint where a hidden Core tool can be denied before Rust dispatch.
- `Epistemos/Engine/AgentToolProvenanceRecorder.swift:26` can persist ordered requested/denied events with bounded metadata and no schema change.

## Recommended slice shape

Instrument only the denied Core `tools/call` policy path in `MCPBridge`. Record requested and denied events with a fixed run id, synthetic tool-call id, sanitized arguments JSON, nil result JSON, bounded metadata, and a generic denial error. Preserve JSON-RPC response shape and all Core/Pro dispatch behavior.

## Failure-proof guardrails

- grep: `rg -n 'recordToolCallPolicyDenial|mcp_bridge_policy_gate|policy_gate' Epistemos/Omega/MCPBridge.swift EpistemosTests/MCPBridgeAgentEventTests.swift`
- log: `Test Suite 'Selected tests' passed`
- test: `EpistemosTests/MCPBridgeAgentEventTests`
