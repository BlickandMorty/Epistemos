---
role: detective
slice: agent-query-engine-agent-event-pr15
concept: AgentQueryEngine backend stream
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §14
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentHarness/AgentQueryEngine.swift:125
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentHarness/AgentBackend.swift:41
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/AppStoreHardeningTests.swift:690
deliberations_consulted:
  - docs/fusion/deliberation/agent_grep_agent_event_pr14_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: false
  canon_says: "Future live emission must be additive instrumentation only"
  code_says: "[paraphrase] AgentQueryEngine already maps backend toolUse/toolResult events without durable provenance"
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentHarness/AgentQueryEngine.swift
load_bearing_quote: "Future live emission must be additive instrumentation only"
verdict: open
usefulness: +1
usefulness_reason: Provides a clean exact seam for PR15 and names privacy boundaries.
---

## Findings
- `AgentQueryEngine.swift:222` already emits `.toolStarted` when a backend streams `.toolUse`.
- `AgentQueryEngine.swift:225` already emits `.toolCompleted` when a backend streams `.toolResult`.
- `AgentBackend.swift:41` defines the provider-agnostic stream event shape, so this slice covers a broader harness seam without provider routing edits.
- `AppStoreHardeningTests.swift:690` already proves this actor can be tested with a fake backend registered under a unique identifier.

## Open questions
- None. The implementation should add an injectable recorder and keep the default existing behavior unchanged.

## Recommendation
Instrument `.toolUse` with requested/started and `.toolResult` with completed/failed. Use a per-turn `agent-query-engine-...` run id, actor id `agent-query-engine`, and the backend tool id/name already present in the stream. Result JSON must contain only output byte count and error boolean.
