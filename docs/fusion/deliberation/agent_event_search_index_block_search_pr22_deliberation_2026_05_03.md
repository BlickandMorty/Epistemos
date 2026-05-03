# AgentEvent SearchIndex Block Search PR22 Deliberation — 2026-05-03

## Slice
Instrument `SearchIndexService.searchBlocks(query:limit:)` and `SearchIndexService.searchBlocksAsync(query:limit:)` with bounded AgentEvent tool provenance.

## Tier
Core. No Pro/Research surfaces, no Hermes, no subprocess, no browser/computer-use, no private framework, and no biometric/Sovereign Gate touchpoint.

## Allowed files/subsystems
- `/Users/jojo/Downloads/Epistemos/Epistemos/Sync/SearchIndexService.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/SearchIndexServiceFusionTests.swift`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/agent-event-search-index-block-search-pr22/`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`

## Forbidden files/subsystems
- RRF SQL, `ReadableBlocksIndex`, `VaultSyncService`, `QueryRuntime`, UI, graph, Rust, generated bindings, EventStore schema, Hermes, CloudLLM, ShadowSearch, InstantRecall, fused search behavior, page-search behavior.

## Canon anchors
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §19
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §22
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` Safe Next Build Order item 3
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 provenance spine hardening

## Workcard match
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Raw Thoughts / Provenance Spine Hardening, AgentEvent runtime coverage continuation after PR21.
- Deviation: none. This is the exact next narrow SearchIndex runtime provenance continuation.

## Required behavior
- Valid non-empty sync block searches emit `requested`, `started`, and terminal `completed` or `failed` AgentEvents through `AgentToolProvenanceSyncRecorder`.
- Valid non-empty async block searches emit the same lifecycle through `AgentToolProvenanceRecorder`.
- Invalid normalized empty inputs return `[]` and emit no events.
- Persisted arguments/results/metadata include only sanitized fields: query character count, query term count, limit, hit count, elapsed milliseconds, surface, source, and closed failure class.
- Persisted data must not include query text, sanitized FTS query, block ids, page ids, snippets, ranks, document body, SQL, GRDB/localized error text, or arbitrary error text.
- Sync block search must not bridge into async recording with `Task`, `Task.detached`, `DispatchQueue.main.sync`, or `MainActor.assumeIsolated`.
- Keep block-search SQL/fallback behavior unchanged.

## Acceptance
- Add failing tests/source guards first for `searchBlocks` and `searchBlocksAsync` lifecycle recording and privacy.
- Add monotonic async tool-id coverage for the new block-search sequence.
- Update source guards so block-search tool names are present only as bounded PR22 surfaces.
- Run the focused xcodebuild command under `set -o pipefail`:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/SearchIndexServiceFusionTests -only-testing:EpistemosTests/SearchIndexServiceAgentEventSourceGuardTests test`

## Failure-proof guardrails (post-merge)
- grep: `rg -n 'search_index\.search_blocks|search_index\.search_blocks_async|recordBlockSearch' Epistemos/Sync/SearchIndexService.swift EpistemosTests/SearchIndexServiceFusionTests.swift`
- log: `/tmp/epistemos-agent-event-search-index-block-pr22-green-pipefail-20260503.log` contains `** TEST SUCCEEDED **`
- test: `EpistemosTests/SearchIndexServiceFusionTests` and `EpistemosTests/SearchIndexServiceAgentEventSourceGuardTests`

## Fleet evidence packet
- `docs/fusion/fleet/agent-event-search-index-block-search-pr22/detectives/search-index-block-search-agent-event.md`
- `docs/fusion/fleet/agent-event-search-index-block-search-pr22/aggregator.md`
- `docs/fusion/fleet/agent-event-search-index-block-search-pr22/claude-red-team/attacks.md`

## Usefulness
usefulness: +1
usefulness_reason: Authorizes one safe block-search provenance patch with privacy and sync-recorder guardrails.
