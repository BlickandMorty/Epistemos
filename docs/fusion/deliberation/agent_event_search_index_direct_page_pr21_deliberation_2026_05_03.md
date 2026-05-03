# AgentEvent SearchIndex Direct Page PR21 Deliberation - 2026-05-03

## Report Before Code

Tier: Core

Sovereign Gate touchpoint: none.

Killer-feature dependency: none directly. This is substrate provenance hardening that keeps later retrieval, audit, Halo, and graph consumers honest.

Allowed files/subsystems:
- `Epistemos/Sync/SearchIndexService.swift`
- `EpistemosTests/SearchIndexServiceFusionTests.swift`
- `docs/fusion/fleet/agent-event-search-index-direct-page-pr21/**`
- `docs/fusion/oversight/PREFLIGHT_52_2026_05_03.md`
- `docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`

Forbidden files/subsystems:
- `Epistemos/Sync/VaultSyncService.swift`
- `Epistemos/Engine/QueryRuntime.swift`
- `Epistemos/Views/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- `Epistemos/State/EventStore.swift`
- generated bindings, Xcode project files, entitlements, OpLog, GraphEvent, Halo, Theater, approval, provider routing, and runtime tool execution.

## Build Order

1. Add failing tests for direct page sync and async search AgentEvents.
2. Add invalid-input and source-guard tests proving normalized-empty queries emit no events and source stays out of forbidden surfaces.
3. Implement minimal provenance in `SearchIndexService.search` and `searchAsync`, reusing the existing AgentEvent recorder architecture.
4. Run focused red/green logs for `SearchIndexServiceFusionTests`.
5. Run source guard and staged path checks.

## Acceptance

- Valid sync direct page search emits requested, started, completed/failed AgentEvents with one run id, monotonic `search-index-page-sync:N` tool call ids, actor `search-index-service`, and surface `search`.
- Valid async direct page search emits requested, started, completed/failed AgentEvents with one run id, monotonic `search-index-page-async:N` tool call ids, actor `search-index-service`, and surface `search_async`.
- Persisted payloads include only query character count, query term count, limit, elapsed milliseconds, hit count, and bounded failure class.
- Persisted payloads exclude query text, page ids, titles, snippets, body text, tags, SQL, GRDB/localized error text, VaultSync caller context, and arbitrary errors.
- Invalid normalized-empty inputs emit no AgentEvents.
- No behavior/ranking/schema/SQL/UI/Rust/Graph/VaultSync changes.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §8
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:285`
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:317`
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:1042`
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:1001`

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance
- Deviation: none; this is a fresh exact runtime instrumentation gate after PR19/PR20.

## Failure-proof guardrails (post-merge)

- grep: `toolName: "search_index.search"`
- grep: `toolName: "search_index.search_async"`
- grep: `directPageSyncSearchToolSequence`
- grep: `directPageAsyncSearchToolSequence`
- log: `✔ Test "direct page search sync records sanitized AgentEvents" passed`
- log: `✔ Test "direct page search async records sanitized AgentEvents" passed`
- test: `SearchIndexServiceFusionTests`
- forbidden staged grep: `git diff --cached --name-only | rg '^(Epistemos/Sync/VaultSyncService.swift|Epistemos/Engine/QueryRuntime.swift|Epistemos/Views/|Epistemos/Graph/|graph-engine/|agent_core/|Epistemos/State/EventStore.swift|Epistemos.xcodeproj|.*entitlements)'` returns no matches.

## Fleet evidence packet

- `docs/fusion/fleet/agent-event-search-index-direct-page-pr21/detectives/search-index-direct-page-agent-event.md`
- `docs/fusion/fleet/agent-event-search-index-direct-page-pr21/aggregator.md`
- `docs/fusion/fleet/agent-event-search-index-direct-page-pr21/claude-red-team/attacks.md` (added after Red Team returns)

## Usefulness

usefulness: +1
usefulness_reason: Closes a clean direct SearchIndex page-search AgentEvent gap without dirty wrapper or graph surfaces.
