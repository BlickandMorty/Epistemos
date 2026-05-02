# Deliberation — AgentQueryEngine AgentEvent Provenance PR15 — 2026-05-02

## Decision
Approved after fleet review. Build PR15 as a narrow Core instrumentation slice for `AgentQueryEngine` backend tool-stream events only.

## Tier
Core. This is in-process Swift harness provenance with no cloud routing changes, no subprocess changes, and no Pro/Research symbols.

## Allowed files
- `Epistemos/Engine/AgentHarness/AgentQueryEngine.swift`
- `EpistemosTests/AgentQueryEngineAgentEventTests.swift`
- `docs/fusion/fleet/agent-query-engine-agent-event-pr15/**`
- `docs/fusion/deliberation/agent_query_engine_agent_event_pr15_deliberation_2026_05_02.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
- `docs/fusion/fleet/REGISTRY.md`

## Forbidden files
- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/Engine/PipelineService.swift`
- `Epistemos/LocalAgent/LocalAgentLoop.swift`
- `Epistemos/Engine/LLMService.swift`
- `Epistemos/Omega/**`
- `Epistemos/State/EventStore.swift`
- `Epistemos/Models/AgentProvenanceEvent.swift`
- `Epistemos/Views/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- generated bindings, Xcode project files, entitlements, DerivedData, `.xcresult`

## Required implementation
- Add an injectable `AgentToolProvenanceRecorder` to `AgentQueryEngineConfig`, defaulting to nil so existing call sites do not change.
- Resolve the recorder lazily inside `AgentQueryEngine`, matching other provenance slices' no-recorder behavior.
- For each `submitMessage` turn, create one run id shaped `agent-query-engine-<UUID>`.
- On backend `.toolUse(id:name:input:)`, emit requested and started events for the backend tool call.
- On backend `.toolResult(id:output:isError:)`, emit completed or failed for the same tool call.
- Persist only sanitized metadata/payloads: backend id, model id, turn index, source/surface, tool call id/name, output byte count, error flag, and duration.
- Never persist prompt, history, system prompt, cwd, tool input data, tool output text, text/thinking deltas, backend logs, URLs, credentials, provider request bodies, or generated responses.

## Acceptance
- Failing test first proves no events are recorded before implementation.
- Green test proves requested/started/completed lifecycle, shared run id, actor id, tool identity, sanitized arguments/result payloads, and no prompt/history/cwd/tool input/output leakage.
- Green test proves failed tool results emit `tool_call_failed` with only bounded failure metadata.
- Existing `AgentQueryEngine` max-turn behavior remains unchanged.

## Canon anchors
- `MASTER_RESEARCH_INDEX_2026_05_02.md §2`
- `MASTER_RESEARCH_INDEX_2026_05_02.md §14`
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7

## Workcard match
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance
- Deviation: none. This is the next exact-gated runtime emission after PR14.

## Failure-proof guardrails (post-merge)
- grep: `toolName: name`
- grep: `agentQueryEngineToolArgumentsJSON`
- forbidden grep: `argumentsJSON.*prompt|argumentsJSON.*history|argumentsJSON.*cwd|resultJSON.*output|resultJSON.*text|toolInput`
- log: `✔ Test "AgentQueryEngine records sanitized backend tool AgentEvents" passed`
- test: `AgentQueryEngine AgentEvent provenance`

## Fleet evidence packet
- `docs/fusion/fleet/agent-query-engine-agent-event-pr15/aggregator.md`
- `docs/fusion/fleet/agent-query-engine-agent-event-pr15/claude-red-team/attacks.md`

## Usefulness
usefulness: +1
usefulness_reason: Adds the next broad, clean AgentEvent seam while preserving strict privacy boundaries.
