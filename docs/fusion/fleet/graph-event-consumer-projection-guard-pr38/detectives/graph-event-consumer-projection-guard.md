---
role: detective
slice: graph-event-consumer-projection-guard-pr38
concept: durable GraphEvent consumer projection guards
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/State/EventStore.swift
  - /Users/jojo/Downloads/Epistemos/Engine/GraphEventAuditProjectionService.swift
  - /Users/jojo/Downloads/Epistemos/Views/Settings/GraphEventVisibilityRow.swift
  - /Users/jojo/Downloads/Epistemos/Engine/HaloController.swift
  - /Users/jojo/Downloads/Epistemos/Views/Halo/ShadowPanelContent.swift
  - /Users/jojo/Downloads/Epistemos/Views/Capture/TraceInspectorView.swift
  - /Users/jojo/Downloads/Epistemos/Engine/QueryRuntime.swift
drift:
  detected: false
load_bearing_quote: "Future live GraphEvent consumer projections only after a new deliberation gate names exact projection files and focused tests."
verdict: closed
usefulness: +1
usefulness_reason: Turns the next live-consumer precondition into a focused guard test.
---

## Findings

- The durable GraphEvent spine is already closed through PR10; the next safe step is a guard that freezes existing consumers as read-only.
- Current consumers are EventStore projection snapshot, audit service, Settings row, Halo ribbon, Trace Inspector summary, and QueryRuntime hint.
- The guard must not edit production or duplicate Claude's value-level `GraphEventProjectionFixtureTests.swift`.

## Recommendation

Add `GraphEventConsumerProjectionGuardTests.swift` as source-guard coverage only, then run a focused Xcode test.
