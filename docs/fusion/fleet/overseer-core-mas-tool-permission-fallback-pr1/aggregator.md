---
role: aggregator
source_fleet: codex-own
slice: overseer-core-mas-tool-permission-fallback-pr1
date: 2026-05-03
detectives_consumed:
  - detectives/overseer-core-mas-tool-permission-fallback.md
web_consumed:
  - web/apple-app-review-guideline-252.md
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts: []
drift_signals:
  - Overseer fallback list includes Pro-style names when live registry permissions are empty.
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
  zero: 1
  minus_one: 0
usefulness: +1
usefulness_reason: Converts a real Core/MAS degraded-registry drift signal into a narrow implementation brief.
---

## Reconciled Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §12 and Apple Guideline 2.5.2 both support the bounded Core/App Store posture; local canon remains the implementation authority.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` marks ToolSurfacePolicy, Omega dispatch, Command Center policy, and ToolTier PR2 closed, so this slice must not reopen those surfaces.
- `Epistemos/Engine/OverseerProtocol.swift:917` is a separate fallback branch; it should fail closed under Core/App Store if registry-derived permissions are unavailable.
- `Epistemos/Bridge/ToolTierBridge.swift:11` already provides the canonical Core allow-list, so this patch should reuse `ToolSurfacePolicy` instead of adding a new policy table.

## Recommended Slice Shape

Patch only `OverseerProtocol` and focused tests. Add a fallback-permission helper that filters the existing hardcoded fallback through `ToolSurfacePolicy.isSurfacedToolName` for Core/App Store, preserving Pro/Research fallback behavior. Add tests that directly exercise the fallback helper for both Core and Pro/Research.

## Failure-Proof Guardrails

- grep: `awk '/private func toolPermissions\\(for route:/{flag=1} /private func permissionMode\\(for tool:/{flag=0} flag {print}' Epistemos/Engine/OverseerProtocol.swift | rg -n 'Self\\.fallbackToolPermissions\\(distribution: \\.currentBuild\\)|OverseerToolPermission\\(toolName: "run_command"'`
- log: `/tmp/epistemos-overseer-core-mas-tool-permission-fallback-pr1-green2-20260503.log` contains `** TEST SUCCEEDED **`
- test: `EpistemosTests/OverseerProtocolTests`
