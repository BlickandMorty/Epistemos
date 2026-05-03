---
role: aggregator
source_fleet: codex-own
slice: omega-tool-registry-core-planning-pr1
date: 2026-05-02
detectives_consumed:
  - detectives/omega-tool-registry-core-planning.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts:
  - id: C1
    sources: [ToolSurfacePolicy round 39, OmegaToolRegistry full planning helpers]
    resolution: keep full runtime registry intact; filter only model/planning visibility.
drift_signals:
  - Omega planner prompt/schema helpers still expose full MCP catalog unless callers manually filter.
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
usefulness_reason: Extends the Core visible-tool guard to Omega planning JSON and prompt surfaces.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §12` requires App Store/MAS hardening to keep Pro-only execution surfaces out of Core.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` now records `ToolSurfacePolicy` as the Core/MAS visible planning guard.
- `OmegaToolRegistry.planningSchemasJson` and `planningPromptBlock()` are separate visible planning surfaces and should use the same distribution-aware filtering.

## Recommended slice shape
Patch only `Epistemos/Omega/MCPBridge.swift` and `EpistemosTests/OmegaToolSchemaGrammarTests.swift`. Add overloads/functions that accept `ToolSurfacePolicy.Distribution`, keep default current-build behavior, and prove Core/App Store schemas/prompt hide terminal, automation, and computer-use tools.

## Failure-proof guardrails
- grep: `rg -n 'surfacedTools\\(distribution|planningSchemas\\(distribution|planningPromptBlock\\(distribution' Epistemos/Omega/MCPBridge.swift EpistemosTests/OmegaToolSchemaGrammarTests.swift`
- log: `** TEST SUCCEEDED **`
- test: `EpistemosTests/ToolSchemaGrammarTests`
