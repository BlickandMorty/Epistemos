# Deliberation - InstantRecall AgentEvent Provenance PR16 - 2026-05-02

## Decision
Approved after fleet review. Build PR16 as a narrow Core instrumentation slice for `InstantRecallService.search(queryText:topK:)` sync recall only.

## Tier
Core. This is in-process Swift recall provenance with no cloud routing changes, no subprocess changes, and no Pro/Research symbols.

## Allowed files
- `Epistemos/KnowledgeFusion/InstantRecallService.swift`
- `EpistemosTests/InstantRecallTests.swift`
- `docs/fusion/fleet/instant-recall-agent-event-pr16/**`
- `docs/fusion/deliberation/instant_recall_agent_event_pr16_deliberation_2026_05_02.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
- `docs/fusion/fleet/REGISTRY.md`

## Forbidden files
- `Epistemos/Engine/ShadowSearchService.swift`
- `Epistemos/Engine/HaloController.swift`
- `Epistemos/Engine/HaloEditorBridge.swift`
- `Epistemos/Views/**`
- `Epistemos/Graph/**`
- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/Engine/PipelineService.swift`
- `Epistemos/LocalAgent/LocalAgentLoop.swift`
- `Epistemos/Engine/LLMService.swift`
- `Epistemos/Omega/**`
- `Epistemos/State/EventStore.swift`
- `Epistemos/Models/AgentProvenanceEvent.swift`
- `graph-engine/**`
- `agent_core/**`
- generated bindings, Xcode project files, entitlements, DerivedData, `.xcresult`

## Required implementation
- Add an injectable `AgentToolProvenanceRecorder` to `InstantRecallService`, defaulting to a normal recorder so existing call sites do not change.
- For each valid sync search, create one run id shaped `instant-recall-<UUID>`.
- Emit requested and started events before calling the Rust `instantRecallSearch(...)` function.
- Emit completed after successful JSON decode, or failed if the returned JSON cannot be encoded/decoded into the expected result shape.
- Persist only sanitized metadata/payloads: query character count, query term count, topK, hit count, document count, elapsed milliseconds, source/surface, and failure class.
- Never persist query text, note ids, note bodies, result text, snippets, vault paths, source text, async recall events, Halo state, ShadowSearch payloads, editor state, graph state, or generated responses.
- Leave `searchAsync(query:topK:)` untouched; ambient recall instrumentation needs a future latency/sampling gate.

## Acceptance
- Failing test first proves no events are recorded before implementation.
- Green test proves requested/started/completed lifecycle, shared run id, actor id, tool identity, sanitized arguments/result payloads, and no query/doc/body leakage.
- Green test proves invalid query/topK inputs do not emit AgentEvents.
- Existing InstantRecall lazy hydration, async hydration, sync metrics, empty input, and async search behavior remain green.

## Canon anchors
- `MASTER_RESEARCH_INDEX_2026_05_02.md §2`
- `MASTER_RESEARCH_INDEX_2026_05_02.md §5`
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7

## Workcard match
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance
- Deviation: none. This is the next exact-gated runtime emission after PR15.

## Failure-proof guardrails (post-merge)
- grep: `toolName: "instant_recall.search"`
- grep: `instantRecallSearchArgumentsJSON`
- forbidden grep: `argumentsJSON.*query|argumentsJSON.*text|argumentsJSON.*doc|resultJSON.*query|resultJSON.*text|resultJSON.*doc|resultJSON.*body`
- log: `✔ Test "Search records sanitized AgentEvents" passed`
- test: `InstantRecall — Service`

## Fleet evidence packet
- `docs/fusion/fleet/instant-recall-agent-event-pr16/aggregator.md`
- `docs/fusion/fleet/instant-recall-agent-event-pr16/claude-red-team/attacks.md`

## Usefulness
usefulness: +1
usefulness_reason: Adds provenance to canonical recall without touching ambient recall, Halo, ShadowSearch, or UI hot paths.
