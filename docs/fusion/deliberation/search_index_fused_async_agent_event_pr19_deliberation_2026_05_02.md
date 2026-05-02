# SearchIndexService Fused Async AgentEvent PR19 Deliberation - 2026-05-02

## Tier
Core. This is local, additive retrieval provenance over the existing RRF fused async search path.

Gate: SovereignGate touchpoint? none.

## Slice
Instrument `SearchIndexService.fusedSearchAsync(query:weights:now:)` with bounded AgentEvent lifecycle emission.

## Canon anchors
- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` - substrate spine includes AgentEvent.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §5` - Halo / recall / search rail.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §8` - existing fused-search instrumentation seam.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md Card 7` - AgentEvent Tool Provenance.

## Current code truth
- `Epistemos/Sync/SearchIndexService.swift:591` is the async RRF fused search method.
- `Epistemos/Sync/SearchIndexService.swift` currently has no `AgentProvenance` or `saveAgentEvent` references.
- `Epistemos/Sync/VaultSyncService.swift:2326` reaches `fusedSearchAsync` behind `RRFFusionFlags.isEnabled`.
- `EpistemosTests/SearchIndexServiceFusionTests.swift:370` already proves async fused search parity against the sync method.

## Allowed files/subsystems
- `Epistemos/Sync/SearchIndexService.swift`
- `EpistemosTests/SearchIndexServiceFusionTests.swift`
- `docs/fusion/fleet/search-index-service-fused-async-agent-event-pr19/**`
- `docs/fusion/deliberation/search_index_fused_async_agent_event_pr19_deliberation_2026_05_02.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
- `docs/fusion/fleet/REGISTRY.md`

## Forbidden files/subsystems
- `Epistemos/Sync/RRFFusionQuery.swift`
- `Epistemos/Sync/VaultSyncService.swift`
- `Epistemos/Engine/QueryRuntime.swift`
- `Epistemos/State/EventStore.swift`
- `Epistemos/Models/AgentProvenanceEvent.swift`
- `Epistemos/Views/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- generated bindings, generated libraries, Xcode project files, entitlements, DerivedData, `.xcresult`

## Implementation contract
- Add `AgentToolProvenanceRecorder?` injection to `SearchIndexService` with a `nil` default so the existing non-MainActor initializer and call sites stay unchanged.
- Store the recorder in actor-isolated `private var agentProvenanceRecorder: AgentToolProvenanceRecorder?`. On first emission, if it is `nil`, set it with `await MainActor.run { AgentToolProvenanceRecorder() }`; subsequent emissions reuse the stored instance. Do not mark `SearchIndexService.init` as `@MainActor`.
- Emit `requested` and `started` after `normalizedSearchTerms(query)` returns non-empty and before `offloadSearch` is awaited. This `started` row means "actor-scope dispatch to the offloaded query path," not "queryQueue work item has started executing."
- Move both `normalizedSearchTerms(query)` and `sanitizeFTS5Query(terms)` to actor scope before `offloadSearch` is awaited; the offload closure receives only the prepared sanitized query string. This intentional executor move keeps the event gate deterministic for small CPU-bounded query prep.
- Emit `completed` or `failed` after `offloadSearch` returns or throws, from the actor scope. Do not call the `@MainActor` recorder from inside the non-async offload closure.
- Terminal-row emission must directly `await recorder.recordToolEvent(...)`; `Task { ... }` and `Task.detached { ... }` are forbidden for lifecycle rows. The `await` precedes `throw error` in the failure branch and precedes `return results` in the success branch.
- Use run ids exactly matching `^search-index-fused-async-[0-9A-F-]{36}$`, tool ids `search-index-fused-async:N`, actor `search-index-service`, tool name `search_index.fused_search_async`, and surface `fused_search_async`.
- Persist only scalar sanitized metadata: query character count, term count, `weights_profile` (`default` or `custom`), now timestamp, hit count, elapsed milliseconds, and bounded failure class.
- Use the closed failure class set `cancelled | sql_error | unknown_error`; derive classes from error type only and never inspect error messages.
- Do not persist query text, sanitized FTS query, result text, snippets, ids, source labels, scores, SQL, GRDB error strings, vault paths, or raw payloads.
- Preserve `fusedSearchAsync` throws behavior, `SearchFusionMetrics`, signposts, empty-query early return, cancellation behavior, and every sync/legacy method.
- Cancellation rows are guaranteed for mid-flight cancellation after `started` has been recorded; pre-flight cancellation before the method reaches normalized terms may emit no rows. Tests must cancel after observing a started-row synchronization point.
- The tool-call-ID counter is actor-isolated, per-service-instance, and monotonic. It must not be static, global, or `nonisolated(unsafe)`.
- Existing async fusion tests must inject a no-op/in-memory recorder where needed so PR19 does not write incidental test rows to production `EventStore.shared`.
- Update `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` to remove stale PR18 open wording and mark PR19 closed when implementation is green.

## Acceptance
- Red test fails before implementation because valid async fused searches produce no AgentEvents.
- Green tests prove requested/started/completed lifecycle for a valid hit.
- Green tests prove valid zero-hit searches complete with `hit_count = 0`.
- Green tests prove mid-flight cancellation after `started` records one terminal failed row with `failure_class=cancelled`.
- Green tests prove empty, whitespace, and empty-after-normalization queries emit no events.
- Green tests prove sync `fusedSearch` remains uninstrumented.
- Green tests prove run IDs match the exact UUID suffix regex and concurrent async calls do not duplicate tool ids.
- Green tests prove custom `FusionWeights` persist only `weights_profile=custom`, not scalar weight values.
- Guardrails prove no protected files, no schema, no RRF SQL, no consumer wrapper, no UI, no Rust, and no generated files changed.

## Workcard match
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance.
- Deviation: none. This is a new fresh live-emission gate naming exact runtime files and focused tests.

## Failure-proof guardrails (post-merge)
- grep: `search-index-fused-async-`
- grep: `toolName: "search_index.fused_search_async"`
- grep: `surface": "fused_search_async"`
- forbidden grep: `(argumentsJSON|resultJSON|errorMessage|metadata).*(query_text|queryText|snippet|score|doc_id|docId|title|body|vault|path|localizedDescription|String\(describing:.*error|sanitized)`
- forbidden grep: `(log\.|os_log|Logger).*\\(error`
- forbidden grep: `Task\\s*(\\.detached)?\\s*\\{[^\\n]*(recordToolEvent|AgentToolProvenanceRecorder)`
- forbidden sync grep: `git grep -n -A 35 "nonisolated public func fusedSearch(" Epistemos/Sync/SearchIndexService.swift | grep -E "(agentProvenanceRecorder|recordToolEvent)"`
- staged guard: `git diff --cached --name-only -- agent_core graph-engine epistemos-shadow Epistemos/Views Epistemos/Graph Epistemos/State/EventStore.swift Epistemos/Models/AgentProvenanceEvent.swift Epistemos/Sync/RRFFusionQuery.swift Epistemos/Sync/VaultSyncService.swift Epistemos/Engine/QueryRuntime.swift Epistemos.xcodeproj`
- log: `✔ Test "fusedSearchAsync records sanitized AgentEvents" passed`
- test: `SearchIndexService - RRF Fusion (Phase 5)`

## Fleet evidence packet
- `docs/fusion/fleet/search-index-service-fused-async-agent-event-pr19/aggregator.md`
- `docs/fusion/fleet/round-19-next-master-plan-slice-selection/claude-side-fleet/aggregator.md`
- `docs/fusion/fleet/search-index-service-fused-async-agent-event-pr19/claude-red-team/attacks.md`
- `docs/fusion/fleet/search-index-service-fused-async-agent-event-pr19/claude-red-team/attacks-r2.md`

## Usefulness
usefulness: +1
usefulness_reason: Closes the next uninstrumented user-reachable RRF fused async retrieval chokepoint with a one-file additive pattern.
