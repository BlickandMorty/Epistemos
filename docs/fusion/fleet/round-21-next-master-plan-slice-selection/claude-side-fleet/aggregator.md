---
role: aggregator
source_fleet: claude-side-fleet
slice: next-master-plan-slice-selection
round: 21
date: 2026-05-02
detectives_consumed:
  - local-canon
web_consumed: []
canon_gaps_opened: []
conflicts: []
drift_signals:
  - "worktree on feature/landing-liquid-wave has 651 modified files spanning App/Engine/Graph/KnowledgeFusion/LocalAgent/Models/Omega/State/Sync/Views; any slice picked must avoid that dirty surface"
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
usefulness_reason: "PR19's contract explicitly leaves the sync rail uncovered, giving an exact parity slice with no canon ambiguity."
---

## Ranked Next Slices

1. **AgentEvent PR20 - `SearchIndexService.fusedSearch` sync provenance.** Recommended. PR19 closed only the async `fusedSearchAsync` rail and explicitly kept sync `fusedSearch` uninstrumented. The async pattern is proven in commit `2d558843`, and the next parity slice can stay inside `Epistemos/Sync/SearchIndexService.swift` plus `EpistemosTests/SearchIndexServiceFusionTests.swift`.

2. **AgentEvent PR21 - `VaultSyncService.searchFull` / `searchFullAsync` provenance.** Useful, but defer because `Epistemos/Sync/VaultSyncService.swift` is already dirty and would commingle with broader landing-wave drift.

3. **Sovereign Gate PR9 - next destructive confirmation surface.** Useful after a new gate names the exact existing destructive popup and forbidden write set.

4. **GraphEvent PR9 - read-only retrieval projection ribbon.** Useful, but defer because likely targets such as `QueryRuntime` or `MeaningAnchorService` are in dirty surfaces.

5. **Core/MAS Release Split Audit.** Low-risk docs-first slice, but less direct than the PR19 parity closure.

## Recommendation

Pick **AgentEvent PR20 - `SearchIndexService.fusedSearch` sync provenance**. It is the strongest autonomous build because it closes a named parity gap with minimum delta, preserves the proven PR19 privacy envelope, avoids protected paths, needs no web validation, and is testable through the existing `SearchIndexServiceFusionTests` source-guard and FTS5-gated runtime harness.

CLAUDE-RETURN: role=SIDE-FLEET | slice=next-master-plan-slice-selection | round=21 | artifact=docs/fusion/fleet/round-21-next-master-plan-slice-selection/claude-side-fleet/aggregator.md | usefulness=+1 | p0=0 | p1=0
