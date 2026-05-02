# Deliberation - InstantRecall Async AgentEvent Provenance PR17 - 2026-05-02

## Decision
Revised after Claude Red Team. Build PR17 as a narrow Core instrumentation slice for `InstantRecallService.searchAsync(query:topK:)` async recall only.

## Tier
Core. This is in-process Swift recall provenance with no cloud routing changes, no subprocess changes, no Pro/Research symbols, and no external dependency.

## Allowed files
- `Epistemos/KnowledgeFusion/InstantRecallService.swift`
- `EpistemosTests/InstantRecallTests.swift`
- `docs/fusion/fleet/instant-recall-async-agent-event-pr17/**`
- `docs/fusion/deliberation/instant_recall_async_agent_event_pr17_deliberation_2026_05_02.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
- `docs/fusion/oversight/PREFLIGHT_16_2026_05_02.md`
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
- generated Swift/header bindings, generated libraries, Xcode project files, entitlements, DerivedData, `.xcresult`

## Required implementation
- Add a failing Swift Testing test first proving valid `searchAsync(query:topK:)` calls currently do not emit AgentEvents.
- For each valid async search, create one run id shaped `instant-recall-async-<UUID>`.
- Emit requested and started events before launching the detached Rust `instantRecallSearch(...)` helper.
- The detached helper must return a typed async outcome carrying results, FFI-only elapsed milliseconds, and an optional closed-set failure class. Do not infer failure from `results.isEmpty`.
- Emit completed after successful async JSON decode, including valid zero-hit searches.
- Emit failed if the async helper reports non-UTF8, unexpected JSON shape, or JSON decode failure.
- Emit failed with `failure_class=cancelled` if the parent task is cancelled after requested/started have been emitted.
- Keep `toolName` as `instant_recall.search` and distinguish async calls through `instant-recall-search-async:N` tool call ids plus `surface=instant_recall_async`.
- Use a separate `asyncSearchSequence` counter so sync `instant-recall-search:N` ids and async `instant-recall-search-async:N` ids advance independently.
- Persist only sanitized metadata/payloads: query character count, query term count, topK, hit count, document count, elapsed milliseconds, source/surface, and failure class.
- `elapsed_ms` measures FFI work only and must be captured inside the detached helper.
- Never persist query text, note ids, note bodies, result text, snippets, vault paths, source text, scores, embeddings, Halo state, ShadowSearch payloads, editor state, graph state, raw FFI JSON, localized error descriptions, or generated responses.
- `errorMessage` must be one of the closed failure slugs: `non_utf8_json`, `unexpected_json_shape`, `json_decode_failure`, or `cancelled`. It must not carry `error.localizedDescription` or any FFI-derived text.
- Preserve async recall behavior: no `lastResults`, `searchCount`, `averageSearchLatencyMs`, or `maxSearchLatencyMs` mutation from the async hot path.
- Preserve hot-path discipline by recording requested/started on the existing MainActor entrypoint and recording exactly one terminal event after awaiting the typed detached outcome. Do not record from inside the detached helper and do not decode the same FFI JSON twice.

## Acceptance
- Red test proves valid async search lacks requested/started/completed AgentEvents before implementation.
- Green test proves requested/started/completed lifecycle, shared run id, async-specific run id prefix, actor id, tool identity, sanitized arguments/result payloads, and no query/doc/body leakage.
- Green test proves invalid async query/topK inputs do not emit AgentEvents.
- Green test proves a valid async search over an empty index emits requested/started/completed with `hit_count=0` and no failure class.
- Green test proves sync and async tool-call counters advance independently.
- Green test proves a cancelled async search emits a terminal failed event with `failure_class=cancelled`.
- Green test proves result JSON uses exactly `hit_count`, `document_count`, and `elapsed_ms`.
- Existing InstantRecall lazy hydration, async hydration, sync metrics, sync AgentEvent provenance, empty input, and async search behavior remain green.
- No UI, graph, Rust, generated binding, EventStore schema, approval, routing, Halo, ShadowSearch, or OpLog files are touched.

## Canon anchors
- `MASTER_RESEARCH_INDEX_2026_05_02.md section 2`
- `MASTER_RESEARCH_INDEX_2026_05_02.md section 5`
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7

## Workcard match
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance
- Deviation: none. Card 7 explicitly names InstantRecall paths beyond sync search, including `searchAsync(query:topK:)`, as future work after a fresh exact-file gate.

## Failure-proof guardrails (post-merge)
- grep: `instant-recall-async-`
- grep: `instant-recall-search-async`
- grep: `surface: "instant_recall_async"`
- forbidden grep: `(argumentsJSON|resultJSON|errorMessage).*(query_text|queryText|note_id|noteId|note_body|noteBody|snippet|embedding|score|raw_json|localizedDescription)`
- log: `Test "Async search records sanitized AgentEvents" passed`
- test: `InstantRecall - Service`

## Fleet evidence packet
- `docs/fusion/fleet/instant-recall-async-agent-event-pr17/aggregator.md`
- `docs/fusion/fleet/instant-recall-async-agent-event-pr17/claude-red-team/attacks.md` (added after Red Team returns)

## Usefulness
usefulness: +1
usefulness_reason: Closes the explicit async recall provenance gap while preserving the hot async recall path, metrics boundary, privacy boundary, and Core-only write set.
