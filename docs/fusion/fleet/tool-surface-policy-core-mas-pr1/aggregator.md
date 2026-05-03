---
role: aggregator
source_fleet: codex-own
slice: tool-surface-policy-core-mas-pr1
date: 2026-05-02
detectives_consumed:
  - detectives/tool-surface-policy-core-mas.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts:
  - id: C1
    sources: [UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md, Epistemos/Bridge/ToolTierBridge.swift]
    resolution: current code is missing the Swift visible-surface mirror; patch policy only.
drift_signals:
- Swift visible-planning policy does not yet enforce a Core/App Store allow-list for visible tools.
tier: Core
sovereign_gate_touchpoint: none
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: false
  freeform_pulse: false
  residency_rail: false
  unclosed_core_blocker: MAS/Core split audit remains active; this slice narrows one visible surface.
ready_for_pipeline_builder: true
missing_artifacts:
  - none
input_usefulness_rollup:
  plus_one: 1
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Converts a documented Core/MAS leak risk into a focused testable policy guard.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §12` and current state require Core/App Store to stay free of Pro tunnels and external subprocess surfaces.
- `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md §2` permits Hermes/CLI/browser/Docker subprocess orchestration only in Pro/Research, never Core.
- `agent_core/src/tools/registry.rs` already names the concrete runtime-forbidden MAS tools; Swift visible-planning policy should fail closed on those names too.
- `Epistemos/Bridge/ToolTierBridge.swift` is the narrowest code seam because it filters `OmegaToolDefinition` before planning exposure.

## Recommended slice shape
Patch only `ToolSurfacePolicy` and `ToolSurfacePolicyTests`. Add a red test for Pro/Research gateway tool names (`bash_execute`, `terminal`, `claude_code`, `codex`, browser/computer-use, `mcp_discover`, `send_message`, etc.) disappearing from Core/App Store visible planning surfaces, then implement a conservative Core/App Store allow-list so newly-added gateway tools fail closed.
After Claude red-team, keep routing primitives such as `route_private` out of the visible Core allow-list unless a future slice proves they cannot dispatch to forbidden surfaces.

## Failure-proof guardrails
- grep: `rg -n 'coreAppStoreAllowedToolNames|bash_execute|browser_navigate|mcp_discover' Epistemos/Bridge/ToolTierBridge.swift EpistemosTests/ToolSurfacePolicyTests.swift`
- log: `** TEST SUCCEEDED **`
- test: `EpistemosTests/ToolSurfacePolicyTests` including sandbox-env override coverage.
