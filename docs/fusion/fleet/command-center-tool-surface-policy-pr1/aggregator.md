---
role: aggregator
source_fleet: codex-own
slice: command-center-tool-surface-policy-pr1
date: 2026-05-02
detectives_consumed:
  - detectives/command-center-tool-surface-policy.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts:
  - id: C1
    sources: [MASTER_RESEARCH_INDEX_2026_05_02.md §12, AgentCommandCenterState.swift]
    resolution: current code can keep Pro/Research behavior but Core/App Store must hide external agent mentions.
drift_signals:
  - ACC context providers advertise Safari/Terminal/Automation without Core/MAS distribution gating.
tier: Core
sovereign_gate_touchpoint: none
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: false
  freeform_pulse: false
  residency_rail: false
  unclosed_core_blocker: Core/MAS visible context-provider leakage in dormant ACC state
ready_for_pipeline_builder: true
missing_artifacts: []
input_usefulness_rollup:
  plus_one: 1
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Converts a visible Core/MAS leakage audit finding into a minimal testable patch.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §12` is decisive: Core/App Store must not surface shell, CLI, or background-agent controls.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §6` and Card 10 establish Hermes/Omega as the Pro/Research gateway for external tools; ACC should not independently advertise external agent mentions in Core.
- `AgentCommandCenterState.swift` already keeps tools registry-backed, so this patch should not alter tool execution, Rust, Omega, provider routing, or UI wiring.

## Recommended slice shape
Add failing `AgentCommandCenterStateTests` for `.coreAppStore` and `.proResearch` catalog/context-provider visibility, then add one constructor-injected distribution, apply `ToolSurfacePolicy` at `rebuildToolCatalog`, and filter built-in context-provider suggestions in `AgentCommandCenterState.refreshContextProviders(...)`.

## Failure-proof guardrails
- grep: `rg -n 'toolSurfaceDistribution|isBuiltInAgentContextProviderVisible|coreAppStoreRefreshToolCatalogFiltersInjectedExternalTools|coreAppStoreManualExternalMentionDoesNotResolve' Epistemos/State/AgentCommandCenterState.swift EpistemosTests/AgentCommandCenterStateTests.swift`
- log: `** TEST SUCCEEDED **`
- test: `EpistemosTests/AgentCommandCenterStateTests`
