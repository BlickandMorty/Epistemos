---
role: aggregator
source_fleet: codex-own
slice: omega-dispatch-core-execution-gate-pr1
date: 2026-05-02
detectives_consumed:
  - detectives/omega-dispatch-core-execution-gate.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts:
  - id: C1
    sources: [Omega Tool Registry Core Planning PR1, MCPBridge.dispatch current code]
    resolution: gate the Swift dispatch entrypoint only; do not unregister tools or alter Rust dispatcher registration.
drift_signals:
  - Planning surfaces are Core-filtered, but raw Swift dispatch still reaches the full Rust registry.
tier: Core
sovereign_gate_touchpoint: none
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: false
  freeform_pulse: false
  residency_rail: false
  unclosed_core_blocker: none
ready_for_pipeline_builder: true
missing_artifacts:
  - none
input_usefulness_rollup:
  plus_one: 1
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Promotes the final red-team P2 from round 40 into a bounded execution-gate slice.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §6` keeps MCP surfaces behind the Hermes/Omega gateway and names `omega-mcp` as the relevant crate.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §12` makes Core/MAS hardening a release split concern.
- Round 40 closed visible planning schemas/prompts/catalog, but Claude red-team correctly left runtime `dispatch(_:)` as a follow-on.
- The minimal patch is Swift-only: parse `tools/list` and `tools/call` at the `MCPBridge` boundary, apply `ToolSurfacePolicy`, and forward allowed calls unchanged.

## Recommended slice shape
Patch `Epistemos/Omega/MCPBridge.swift` and `EpistemosTests/OmegaToolSchemaGrammarTests.swift` only. Add red tests proving Core/App Store dispatch hides Pro tools from `tools/list`, denies `run_command`, and still allows `read_file`. Keep default `.currentBuild` behavior and Pro/Research forwarding intact.

## Failure-proof guardrails
- grep: `dispatch(_ requestJson: String, distribution:`
- grep: `policyGateResponse`
- log: `** TEST SUCCEEDED **`
- test: `EpistemosTests/ToolSchemaGrammarTests`
