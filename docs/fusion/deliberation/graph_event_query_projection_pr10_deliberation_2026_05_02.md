# GraphEvent Query Projection PR10 Deliberation - 2026-05-02

Slice: `graph-event-query-projection-pr10`

Tier: Core

## Decision

Approved: add a read-only GraphEvent projection hint to QueryRuntime full-text retrieval. The hint consumes a bounded durable GraphEvent projection snapshot only as an ordering hint for existing retrieval candidates. It does not create a new search source, mutate an index, or touch graph renderer state.

## Files touched

- `Epistemos/Engine/QueryRuntime.swift`
- `EpistemosTests/QueryRuntimeTests.swift`
- `docs/fusion/fleet/graph-event-query-projection-pr10/**`
- `docs/fusion/deliberation/graph_event_query_projection_pr10_deliberation_2026_05_02.md`
- `docs/fusion/oversight/PREFLIGHT_47_2026_05_02.md`
- `docs/fusion/fleet/REGISTRY.md`

## Protected paths

- Forbidden: `Epistemos/Views/Graph/**`, `Epistemos/Graph/**`, `graph-engine/**`, `agent_core/**`, `epistemos-core/**`, `Epistemos/Views/Notes/ProseEditor*.swift`, generated bindings, Xcode project files, entitlements, DerivedData, `.xcresult`.
- Not touched by this slice.

## Gate

SovereignGate touchpoint: none. This slice adds no popup, permission prompt, auth prompt, destructive action, external tool, or cloud route.

## Risks

- P1: QueryRuntime is already dirty from earlier RRF fused-search work. Stage only PR10 hunks, not unrelated RRF hunks.
- P1: GraphEvent projection must not become a second truth system. It may only hint existing candidates.
- P2: Env-gated default provider must be off unless `EPISTEMOS_GRAPH_EVENT_QUERY_PROJECTION_V1=1`.

## Verification

- Red: `/tmp/epistemos-graph-event-query-projection-pr10-red-20260502.log`
- Green: `/tmp/epistemos-graph-event-query-projection-pr10-green-20260502.log`
- Command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/QueryRuntimeTests -only-testing:EpistemosTests/GraphEventAuditProjectionTests test`
- Guard: `git diff --check`

## Rollback

Remove the QueryRuntime projection-hint helper/provider, the two focused tests, and this slice's docs.

## Stop triggers

- The implementation needs `SearchIndexService`, `InstantRecallService`, `MeaningAnchorService`, `EventStore`, graph renderer, Rust, generated bindings, UI, timers, polling, repair, or mutation writes.
- The hint creates new results that were not returned by full-text retrieval.
- The default provider reads EventStore when the env flag is off.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §10
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §22

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 8 - Durable GraphEvent Mutation Mapping
- Deviation: This is a named future live-consumer gate after PR9. It narrows the write set to QueryRuntime-only hinting.

## Failure-proof guardrails (post-merge)

- grep: `rg -n "GraphEventProjectionHint|graphEventProjectionSnapshotProvider|EPISTEMOS_GRAPH_EVENT_QUERY_PROJECTION_V1" Epistemos/Engine/QueryRuntime.swift`
- forbidden grep: `rg -n "saveGraphEvent|saveMutationEnvelope|GraphEventAuditProjectionService|InstantRecallService|MeaningAnchorService|Timer|DispatchSourceTimer|repeatForever" Epistemos/Engine/QueryRuntime.swift` returns no matches.
- log: `Test "GraphEvent projection hint only reorders existing equal-score candidates" passed`
- test: `QueryRuntimeTests`

## Fleet evidence packet

- `docs/fusion/fleet/graph-event-query-projection-pr10/aggregator.md`
- `docs/fusion/fleet/graph-event-query-projection-pr10/claude-red-team/attacks.md`

## Usefulness

usefulness: +1

usefulness_reason: Advances live GraphEvent consumer projection while preserving QueryRuntime/SearchIndex/Graph/Rust boundaries.
