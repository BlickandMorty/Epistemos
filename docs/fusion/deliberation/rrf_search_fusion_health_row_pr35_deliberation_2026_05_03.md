# rrf-search-fusion-health-row-pr35 deliberation - 2026-05-03

Slice:          RRF Phase 6 Search Fusion Health row
Tier:           Both
Files touched:
- `Epistemos/Sync/RRFFusionQuery.swift`
- `Epistemos/Views/Settings/SearchFusionHealthRow.swift`
- `Epistemos/Views/Settings/SettingsView.swift`
- `EpistemosTests/SearchFusionHealthRowTests.swift`
- Round 68 fleet, registry, current-state, and guard docs
Protected paths: none
Gate:           SovereignGate touchpoint? none
Risks:          P1 if the row flips `EPISTEMOS_RRF_FUSION_V1`; P1 if it polls forever; P2 if it reports metrics not backed by `SearchFusionMetrics`.
Verification:   focused Swift Testing suite plus source greps; logs under `/tmp/epistemos-rrf-search-fusion-health-row-pr35-*.log`
Rollback:       remove the Settings mount and the new row/notification tests; metrics remain harmless.
Stop triggers:
- Any patch changes RRF SQL scoring, default flag behavior, QueryRuntime, VaultSyncService, graph, Rust, Hermes, or generated bindings.
- Any patch claims dogfood completion or MAS default-on status.
- Any patch introduces timers/polling loops in the Search Fusion row.

## Intent

Close the observable half of RRF Phase 6 by making cross-index fusion health visible in Settings. This does not complete the 3-day dogfood requirement and does not flip the flag default.

## Canon Anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md §2`
- `docs/RRF_FUSION_PROMPT.md` Phase 6
- `docs/RRF_FUSION_DESIGN.md` §10 and §14
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 11

## Workcard Match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 11, continuation after PR34.
- Deviation: Card 11 closed PR34 only. PR35 is a narrow follow-up authorized by Card 11 stop triggers and the canonical RRF Phase 6 docs; it intentionally omits the dogfood/default-flip half.

## Acceptance

- Settings Diagnostics mounts `SearchFusionHealthRow()`.
- `SearchFusionHealthRow` reads only `SearchFusionMetrics.shared.snapshot()`.
- The row displays flag state, last query detail, p95, hit distribution, and last error if present.
- Metric changes can refresh the row without a polling loop.
- Tests prove the row is read-only, mounted, event-driven, and no default flag flip is present.

## Failure-Proof Guardrails (post-merge)

- grep: `rg -n 'while !Task\\.isCancelled|Timer|DispatchSourceTimer|repeatForever' Epistemos/Views/Settings/SearchFusionHealthRow.swift`
- log: `Test Suite 'Selected tests' passed`
- test: `EpistemosTests/SearchFusionHealthRowTests`

## Fleet Evidence Packet

- `docs/fusion/fleet/rrf-search-fusion-health-row-pr35/aggregator.md`
- `docs/fusion/fleet/rrf-search-fusion-health-row-pr35/claude-red-team/attacks.md` (added after Red Team returns)

## Usefulness

usefulness: +1
usefulness_reason: Turns a documented deferred observability gap into a bounded, testable Settings diagnostic while preserving the Core-safe flag boundary.
