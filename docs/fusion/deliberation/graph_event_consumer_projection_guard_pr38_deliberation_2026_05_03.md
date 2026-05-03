# GraphEvent Consumer Projection Guard PR38 - Deliberation

## Classification

- Tier: Core
- Change type: test-only source guard
- Canon anchor: `MASTER_RESEARCH_INDEX_2026_05_02.md §2`
- Workcard: `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 8

## Scope

Add `EpistemosTests/GraphEventConsumerProjectionGuardTests.swift` to prove the existing durable GraphEvent consumers stay read-only:

- `EventStore.graphEventProjectionSnapshot(limit:)`
- `GraphEventAuditProjectionService`
- `GraphEventVisibilityRow`
- `HaloController` + `ShadowPanelContent`
- `TraceInspectorView`
- `QueryRuntime` projection hint

## Non-goals

- No production code edits.
- No graph renderer, graph-engine, OpLog, EventStore schema, repair, mutation, polling, timer, Halo behavior, or QueryRuntime behavior changes.
- No staging of Claude's parallel-agent outputs.

## Acceptance

- Focused Xcode test passes for `GraphEventConsumerProjectionGuardTests`.
- Guard grep proves no protected production paths were staged.
- Forbidden-token source scans stay green for mutation, renderer, polling, timer, OpLog, and graph-engine drift.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md §2`
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` Safe Next Build Order item 3
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 8

## Workcard match

- Card: Durable GraphEvent Mutation Mapping, future live projection precondition.
- Deviation: this is a guard-only precondition, not a live consumer.

## Failure-proof guardrails

- grep: `GraphEventConsumerProjectionGuardTests` in `EpistemosTests/GraphEventConsumerProjectionGuardTests.swift`
- log: `✔ Suite "GraphEvent Consumer Projection Guards" passed`
- test: `GraphEventConsumerProjectionGuardTests`

## Fleet evidence packet

- `docs/fusion/fleet/graph-event-consumer-projection-guard-pr38/aggregator.md`

## Usefulness

usefulness: +1
usefulness_reason: Blocks future GraphEvent projection drift before live consumer work expands.
