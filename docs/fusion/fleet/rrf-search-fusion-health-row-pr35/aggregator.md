---
role: aggregator
source_fleet: codex-own
slice: rrf-search-fusion-health-row-pr35
date: 2026-05-03
detectives_consumed:
  - detectives/rrf-search-fusion-health.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts:
  - id: C1
    sources: [docs/RRF_FUSION_PROMPT.md, docs/RRF_FUSION_DESIGN.md, Epistemos/Views/Settings/SearchFusionHealthRow.swift]
    resolution: Phase 6 observability may land now; dogfood/default flip remains deferred per design §10 and Card 11 stop triggers.
drift_signals:
  - Draft SearchFusionHealthRow uses polling; replace with notification-driven refresh before commit.
tier: Both
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
usefulness_reason: Converts a deferred RRF Phase 6 observability requirement into a small, testable UI/metrics slice.
---

## Reconciled Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` anchors the concept and code sources for RRF, metrics, and Search Fusion Health.
- `docs/RRF_FUSION_PROMPT.md:92` requires a Settings row with last latency, hit distribution, and p95.
- `docs/RRF_FUSION_DESIGN.md:290` says the feature flag remains unset by default; PR35 must not change that.
- `Epistemos/Sync/RRFFusionQuery.swift:43` already owns `SearchFusionMetrics`, so the row should subscribe to that metrics surface.

## Recommended Slice Shape

Patch `SearchFusionMetrics` to publish a lightweight change notification, patch `SearchFusionHealthRow` to refresh on notification and remove polling, mount `SearchFusionHealthRow()` in Settings Diagnostics, and add focused Swift Testing source guards plus metric snapshot tests.

## Failure-Proof Guardrails

- grep: `rg -n 'while !Task\\.isCancelled|Timer|DispatchSourceTimer|repeatForever' Epistemos/Views/Settings/SearchFusionHealthRow.swift`
- log: `Test Suite 'Selected tests' passed`
- test: `EpistemosTests/SearchFusionHealthRowTests`
