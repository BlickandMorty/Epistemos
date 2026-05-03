---
role: aggregator
source_fleet: codex-own
slice: core-mas-tooltier-execution-symbol-gate-pr2
date: 2026-05-03
detectives_consumed:
  - detectives/core-mas-tooltier-execution-symbol-gate.md
web_consumed: []
claude_side_fleet_consumed:
  - none
canon_gaps_opened: []
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
usefulness_reason: Converts an open release-split seam into a two-file execution guard.
---

## Reconciled Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §12 makes Core/App Store release separation an active authority lane.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:1064` says the previous Core/MAS work closed prompt/policy/visibility, not every runtime execution seam.
- `Epistemos/Omega/MCPBridge.swift:260` is the current runtime pattern: check `ToolSurfacePolicy` before forwarding `tools/call`.
- `Epistemos/Bridge/ToolTierBridge.swift:217` lacks the equivalent distribution-aware execution preflight.

## Recommended Slice Shape

Patch only `ToolTierBridge` and its focused tests. Do not touch ChatCoordinator, PipelineService, Omega dispatch, Rust, providers, entitlements, project files, graph, or editor code. The bridge should fail closed for hidden Core/App Store tool names and preserve Pro/Research behavior.

## Failure-Proof Guardrails

- grep: `rg -n "distribution: ToolSurfacePolicy.Distribution|Tool not found:|toolExecutorDeniesCoreAppStoreHiddenTools" Epistemos/Bridge/ToolTierBridge.swift EpistemosTests/ToolSurfacePolicyTests.swift`
- log: `** TEST SUCCEEDED **`
- test: `EpistemosTests/ToolSurfacePolicyTests`
