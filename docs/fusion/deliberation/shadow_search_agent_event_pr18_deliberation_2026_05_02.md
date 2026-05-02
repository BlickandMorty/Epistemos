# ShadowSearch AgentEvent Provenance PR18 Deliberation - 2026-05-02

Slice:          ShadowSearch AgentEvent provenance PR18
Tier:           Core
Files touched:
- `Epistemos/Engine/ShadowSearchService.swift`
- `EpistemosTests/ShadowServicesTests.swift`
- `docs/fusion/fleet/shadow-search-agent-event-pr18/**`
- `docs/fusion/deliberation/shadow_search_agent_event_pr18_deliberation_2026_05_02.md`
- `docs/fusion/oversight/PREFLIGHT_18_2026_05_02.md`
- `docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/fleet/REGISTRY.md`
Protected paths:
- `agent_core/**`
- `epistemos-shadow/**`
- `graph-engine/**`
- `Epistemos/Graph/**`
- `Epistemos/Views/**`
- `Epistemos/State/EventStore.swift`
- `Epistemos/Models/AgentProvenanceEvent.swift`
- generated UniFFI bindings and Xcode project files
Gate:           SovereignGate touchpoint? none
Risks:          P1 actor/MainActor recorder hop; P1 privacy regression if raw query/hit/error text is persisted; P1 behavior drift if `searchOrThrow` or `stats` changes.
Verification:   Red focused test to `/tmp/epistemos-shadow-search-agent-event-pr18-red-20260502.log`; green focused test to `/tmp/epistemos-shadow-search-agent-event-pr18-green-20260502.log`; `git diff --check`; protected-path and privacy greps.
Rollback:       Revert only the PR18 exact files; no schema, binding, UI, Rust, or project changes.
Stop triggers:
- Any need to edit HaloController, HaloEditorBridge, ContextualShadowsState, Halo views, graph, Rust, generated bindings, EventStore schema, or AgentProvenanceEvent model.
- Any persisted query text, hit ID, title, snippet, score, source, raw FFI payload, localized error string, vault path, or user content.
- Any change to `searchOrThrow(text:domain:limit:)`, `stats()`, approval, routing, UI, or ShadowFFIClient behavior.
- Claude Red Team returns unresolved P0/P1 attacks.

## Intent

PR18 closes the next Card 7 provenance blind spot by recording sanitized AgentProvenanceEvent lifecycle rows at the live ShadowSearch backend boundary. This captures Halo/Contextual Shadows ambient-recall searches from one service chokepoint without touching UI, graph, Rust, EventStore schema, or generated bindings.

## Evidence

- `MASTER_RESEARCH_INDEX_2026_05_02.md §5` says ShadowSearchService is the V0 production-mounted backend route and code anchor.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` places AgentEvent in the substrate spine.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md Card 7` records PR16/PR17 closed for InstantRecall and leaves ShadowSearch as the next symmetric backend.
- Current code at `Epistemos/Engine/ShadowSearchService.swift:31` has one async `search` method that returns hits or catches FFI errors and returns `[]`.

## Implementation Contract

- Add an injectable `AgentToolProvenanceRecorder` to `ShadowSearchService`, defaulting to the existing production recorder so existing call sites remain unchanged.
- Record only valid search calls: non-empty normalized text and positive limit. Invalid/no-op calls (`text` trims empty or `limit <= 0`) return `[]` and emit no AgentEvents.
- For valid calls, record `toolCallRequested`, `toolCallStarted`, and exactly one terminal row: `toolCallCompleted` or `toolCallFailed`.
- Use run IDs shaped `shadow-search-<uuid>`, tool-call IDs shaped `shadow-search:<N>`, actor id `shadow-search-service`, and tool name `shadow_search.search`.
- Tool-call IDs are per-service-instance monotonic counters starting at 1. UUID run IDs are the cross-event join key; tool-call IDs alone are not globally unique.
- Use exactly `surface = "shadow_search"` and `source = "shadow_search_service"`.
- Persist only bounded JSON and metadata: domain, limit, query char count, query term count, hit count, elapsed milliseconds, and bounded failure class.
- The only allowed `failure_class` / `errorMessage` slugs are `invalid_input`, `not_found`, `io_failure`, `backend_failure`, `rust_panic`, `unknown_code`, `cancelled`, and `unknown_error`.
- A cancelled call must emit terminal `toolCallFailed`, `status = .failed`, `failure_class = "cancelled"`, and `errorMessage = "cancelled"`.
- Recorder calls may cross to the existing `@MainActor` `AgentToolProvenanceRecorder`, but only as bounded lifecycle awaits around the actor search. No new EventStore schema, singleton, static mutable state, or alternate recorder abstraction is allowed in PR18.
- Preserve current `search` success behavior and catch-to-empty behavior. Do not touch `searchOrThrow`, `stats`, `ShadowFFIClient`, `RustShadowFFIClient`, EventStore schema, AgentProvenanceEvent, Halo, views, graph, Rust, or generated bindings.
- `searchOrThrow` remains intentionally unrecorded because it is the developer/error surface and may expose raw error details that AgentEvent must not persist.

## Acceptance

- Red test fails before implementation because `ShadowSearchService.search` emits no AgentEvents.
- Green tests prove lifecycle rows for hit, zero-hit, thrown failure, cancellation, invalid input no-op, sanitized payloads, exact `surface = "shadow_search"`, and no changes to `searchOrThrow` / `stats`.
- Green tests prove result payload key whitelists, closed failure-class membership, `errorMessage` equals the failure slug, and per-instance monotonic tool-call IDs.
- All `ShadowSearchService` tests in `ShadowServicesTests.swift` inject an in-memory recorder sink, so test runs do not write AgentEvents to production `EventStore.shared`.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ShadowServicesTests test` succeeds.
- Guard greps show no protected-path, tier-leakage, or privacy leak hits in the PR18 diff.

## Canon anchors

- MASTER_RESEARCH_INDEX_2026_05_02.md §2
- MASTER_RESEARCH_INDEX_2026_05_02.md §5
- AGENT_BUILD_WORKCARDS_2026_05_01.md Card 7

## Workcard match

- AGENT_BUILD_WORKCARDS_2026_05_01.md card: Card 7 - AgentEvent Tool Provenance
- Deviation: none

## Failure-proof guardrails (post-merge)

- grep: `rg -n "(query_text|queryText|snippet|score|doc_id|docId|title|body|vault|path|localizedDescription|String\\(describing:.*error)" Epistemos/Engine/ShadowSearchService.swift EpistemosTests/ShadowServicesTests.swift`
- log: `/tmp/epistemos-shadow-search-agent-event-pr18-green-20260502.log` contains `** TEST SUCCEEDED **`.
- test: `EpistemosTests/ShadowServicesTests`

## Fleet evidence packet

- docs/fusion/fleet/shadow-search-agent-event-pr18/aggregator.md
- docs/fusion/fleet/shadow-search-agent-event-pr18/claude-red-team/attacks.md

## Usefulness

usefulness: +1
usefulness_reason: Authorizes a narrow live-backend provenance slice that closes the next Card 7 blind spot without expanding into protected Halo, graph, Rust, or schema work.
