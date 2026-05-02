# SearchIndexService Fused Sync AgentEvent PR20 Deliberation - 2026-05-02

## Tier
Core. This is local retrieval provenance over the existing RRF fused sync search path. PR0 has closed the previous sync recorder blocker by adding `AgentToolProvenanceSyncRecorder`.

Gate: SovereignGate touchpoint? none.

## Slice
Implement bounded AgentEvent lifecycle rows for `SearchIndexService.fusedSearch(query:weights:now:)` after PR19 and PR0.

## Canon Anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` - substrate spine includes AgentEvent.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §5` - recall/search rail and RRF context.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md Card 7` - AgentEvent Tool Provenance.
- `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md §3.6` - architectural-invariant audit gates.

## Current Code Truth

- `Epistemos/Sync/SearchIndexService.swift:563` is `nonisolated public func fusedSearch(...)`.
- `Epistemos/Sync/SearchIndexService.swift:597` is the async PR19-instrumented `fusedSearchAsync(...)`.
- `Epistemos/Engine/AgentToolProvenanceRecorder.swift` now exposes `AgentToolProvenanceSyncRecorder` for synchronous nonisolated call sites.
- `Epistemos/State/EventStore.swift:649` exposes nonisolated durable `saveAgentEvent(_:)`, but the recorder owns run-local event sequencing and normalization.
- `EpistemosTests/CognitiveSubstrateTests.swift` proves the sync recorder preserves payload semantics and forbidden-bridge boundaries.

## Allowed Files/Subsystems

- `Epistemos/Sync/SearchIndexService.swift`
- `EpistemosTests/SearchIndexServiceFusionTests.swift`
- Deliberation/fleet docs under `docs/fusion/**`.

## Forbidden Files/Subsystems

- `Epistemos/Sync/VaultSyncService.swift`
- `Epistemos/Engine/QueryRuntime.swift`
- `Epistemos/State/EventStore.swift`
- `Epistemos/Models/AgentProvenanceEvent.swift`
- `Epistemos/Views/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- generated bindings, generated libraries, Xcode project files, entitlements, DerivedData, `.xcresult`

## Implementation Contract

- Do **not** call `AgentToolProvenanceRecorder.recordToolEvent(...)` from `fusedSearch`; use `AgentToolProvenanceSyncRecorder`.
- Do **not** change `fusedSearch` from synchronous `nonisolated` to actor-isolated/async in this slice; production callers depend on the direct search API.
- Do **not** duplicate the recorder's event sequencing and privacy logic inside `SearchIndexService`.
- Record requested, started, and completed/failed rows only after query normalization accepts non-empty terms.
- Persist bounded metadata only: surface, query character count, term count, weights profile, now timestamp, hit count, elapsed milliseconds, and closed failure class.
- Preserve query behavior, `SearchFusionMetrics`, signposts, empty-query early return, RRF SQL, VaultSyncService, QueryRuntime, UI, graph, Rust, generated bindings, and EventStore schema.

## Acceptance

- Sync fused search records sanitized requested, started, and completed/failed AgentEvents for valid non-empty queries.
- Invalid or unsanitizable sync inputs do not record AgentEvents.
- Query text, sanitized FTS query, hit ids, titles, snippets, scores, source labels, document bodies, vault paths, SQL, GRDB error strings, localized descriptions, scalar weight values, and arbitrary error text are not persisted.
- Source guards prove no `Task`, `Task.detached`, `DispatchQueue.main.sync`, or `MainActor.assumeIsolated` bridge patterns enter the sync provenance path.

## Workcard Match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance.
- Deviation: This PR20 depends on the separate PR0 sync recorder enabler and must not re-open PR0's shared-event factory.

## Failure-Proof Guardrails (Post-Merge)

- grep: `nonisolated public func fusedSearch(`
- grep: `AgentToolProvenanceSyncRecorder`
- grep: `toolName: "search_index.fused_search"`
- grep: `"surface": "fused_search"`
- forbidden grep: `Task\\s*(\\.detached)?\\s*\\{[^\\n]*(recordToolEvent|AgentToolProvenanceRecorder)`
- forbidden grep: `DispatchQueue\\.main\\.sync|MainActor\\.assumeIsolated`
- log: `fusedSearch sync records sanitized AgentEvents`
- test: `SearchIndexServiceAgentEventSourceGuardTests`

## Fleet Evidence Packet

- `docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/aggregator.md`
- `docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/detectives/agent-event-provenance.md`
- `docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/detectives/search-index-fused-sync.md`
- `docs/fusion/fleet/round-21-next-master-plan-slice-selection/claude-side-fleet/aggregator.md`
- `docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/claude-red-team/attacks.md`
- `docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/claude-red-team/attacks-after-pr0.md`
- `docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/codex-red-team/attacks-after-pr0.md`

## Usefulness

usefulness: +1
usefulness_reason: Authorizes the now-unblocked sync provenance patch while preserving the no-fire-and-forget provenance rule.
