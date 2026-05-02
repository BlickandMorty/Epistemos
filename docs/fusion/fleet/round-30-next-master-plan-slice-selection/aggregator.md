---
role: aggregator
source_fleet: codex-own
slice: next-master-plan-slice-selection-round-30
date: 2026-05-02
detectives_consumed:
  - docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
  - docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
web_consumed: []
claude_side_fleet_consumed:
  - claude-side-fleet/aggregator.md
canon_gaps_opened: []
conflicts:
  - id: C1
    sources: [current-state open list, committed PR20 code]
    resolution: "Current-state still-open prose needs a follow-up refresh to include PR18-PR20; code and commits win."
drift_signals:
  - "AgentEvent PR20 is now committed, so PR21/VaultSync wrapper work should not double-instrument fused-search chokepoints."
tier: Core
sovereign_gate_touchpoint: new
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: true
  freeform_pulse: false
  residency_rail: false
  unclosed_core_blocker: none
ready_for_pipeline_builder: true
missing_artifacts: []
input_usefulness_rollup:
  plus_one: 1
  zero: 2
  minus_one: 1
usefulness: +1
usefulness_reason: Selects a clean, non-manual Sovereign Gate follow-up while runtime provenance candidates collide with dirty protected files.
---

## Reconciled Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` and `§17` keep Sovereign Gate as a killer Core feature, and Card 9 allows future confirmation-surface migrations when each surface is explicitly named.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` still lists runtime AgentEvent and live GraphEvent work as open, but the best immediate AgentEvent wrappers hit dirty `VaultSyncService`/`QueryRuntime` surfaces and risk double-instrumenting already-closed PR19/PR20 chokepoints.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9 has PR1-PR8 closed and explicitly allows future confirmation-surface migration PRs after a new exact gate.
- `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift` is clean and contains existing destructive model-vault folder/file delete alert buttons that currently call `delete(target)` directly after the alert confirmation.

## Recommended Next Slice

Build `sovereign-gate-model-vault-delete-pr9`: route existing Model Vaults sidebar destructive file/folder delete confirmation through the shared `AppBootstrap` `SovereignGate` with `.deviceOwnerAuthentication`, preserving the current alert, target capture, delete implementation, workspace-page cleanup, and refresh behavior.

## Comparison Verdicts

- AgentEvent PR21 wrapper instrumentation: `0` useful later, but risky now because `VaultSyncService` is dirty and direct wrappers can double-record PR19/PR20 SearchIndex provenance.
- Live GraphEvent consumer projection: `0` useful later, but risky now because `QueryRuntime`, `Graph/**`, and `Views/Graph/**` are dirty/protected.
- Sovereign Gate Model Vault delete PR9: `+1` clean, exact, Core, non-manual, and directly extends the already-closed PR5-PR8 confirmation migration pattern.
- R15 live MLX tok/s: `0` useful only under sufficient memory/thermal conditions; current prior evidence says the sentinel run was memory-blocked.
- R16 runtime/manual closure: `0` deferred because the user asked for code/tests now, not manual runtime verification yet.
- Claude side-fleet: `-1` because the CLI returned no artifact.

## Failure-Proof Guardrails

- grep: `enum ModelVaultDeletionSovereignGate`
- grep: `requestDeleteAuthorization`
- forbidden grep: `LocalAuthentication|LAContext|canEvaluatePolicy|evaluatePolicy` outside `Epistemos/Sovereign/SovereignGate.swift`
- log: `Model vault deletes map to destructive Sovereign Gate requirements`
- test: `SovereignGateTests`
