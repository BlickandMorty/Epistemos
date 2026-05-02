# SearchIndexService Fused Sync AgentEvent PR20 Deliberation - 2026-05-02

## Tier
Core. This is local retrieval provenance over the existing RRF fused sync search path, but the current implementation is blocked before code because the method is synchronous and `nonisolated`.

Gate: SovereignGate touchpoint? none.

## Slice
Evaluate whether `SearchIndexService.fusedSearch(query:weights:now:)` can safely record bounded AgentEvent lifecycle rows after PR19.

## Canon Anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` - substrate spine includes AgentEvent.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §5` - recall/search rail and RRF context.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md Card 7` - AgentEvent Tool Provenance.
- `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md §3.6` - architectural-invariant audit gates.

## Current Code Truth

- `Epistemos/Sync/SearchIndexService.swift:563` is `nonisolated public func fusedSearch(...)`.
- `Epistemos/Sync/SearchIndexService.swift:597` is the async PR19-instrumented `fusedSearchAsync(...)`.
- `Epistemos/Engine/AgentToolProvenanceRecorder.swift:3` marks the recorder `@MainActor`.
- `Epistemos/State/EventStore.swift:649` exposes nonisolated durable `saveAgentEvent(_:)`, but the recorder owns run-local event sequencing and normalization.
- `EpistemosTests/SearchIndexServiceFusionTests.swift:582` currently proves sync `fusedSearch` remains uninstrumented.

## Allowed Files/Subsystems

- Deliberation/fleet docs under `docs/fusion/**`.
- No production code is approved by this brief yet.

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

- Do **not** issue a code order that calls `AgentToolProvenanceRecorder.recordToolEvent(...)` from `fusedSearch` with fire-and-forget `Task`, `Task.detached`, `DispatchQueue.main.sync`, or `MainActor.assumeIsolated`.
- Do **not** change `fusedSearch` from synchronous `nonisolated` to actor-isolated/async in this slice; production callers depend on the direct search API.
- Do **not** duplicate the recorder's event sequencing and privacy logic inside `SearchIndexService`.
- Acceptable next paths are:
  - Open an enabling slice that makes recorder/event construction sync-safe with focused regression tests across existing AgentEvent emitters.
  - Keep sync `fusedSearch` intentionally direct and designate `fusedSearchAsync` as the provenance-bearing RRF fused search rail.
- Any later implementation must preserve query behavior, `SearchFusionMetrics`, signposts, empty-query early return, RRF SQL, VaultSyncService, QueryRuntime, UI, graph, Rust, generated bindings, and EventStore schema.

## Acceptance

- Red Team attacks this blocker brief before any Kimi/code order.
- If Red Team finds a safe narrow implementation path, Codex revises the brief and re-runs the red-team gate.
- If Red Team agrees the current direct PR20 patch is unsafe, close PR20 as blocked and select the next safe master-plan slice.

## Workcard Match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance.
- Deviation: This deliberation does not authorize code yet because the sync API/recorder isolation boundary is materially different from PR19.

## Failure-Proof Guardrails (Post-Merge)

- grep: `nonisolated public func fusedSearch(`
- grep: `@MainActor\nfinal class AgentToolProvenanceRecorder`
- forbidden grep: `Task\\s*(\\.detached)?\\s*\\{[^\\n]*(recordToolEvent|AgentToolProvenanceRecorder)`
- forbidden grep: `DispatchQueue\\.main\\.sync|MainActor\\.assumeIsolated`
- log: `CLAUDE-RETURN: role=RED-TEAM`
- test: `SearchIndexServiceAgentEventSourceGuardTests`

## Fleet Evidence Packet

- `docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/aggregator.md`
- `docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/detectives/agent-event-provenance.md`
- `docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/detectives/search-index-fused-sync.md`
- `docs/fusion/fleet/round-21-next-master-plan-slice-selection/claude-side-fleet/aggregator.md`
- `docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/claude-red-team/attacks.md` (added after Red Team returns)

## Usefulness

usefulness: +1
usefulness_reason: Prevents a plausible but unsafe parity patch from violating Swift actor isolation or the no-fire-and-forget provenance rule.
