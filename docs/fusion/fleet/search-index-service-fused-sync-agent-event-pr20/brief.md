# SearchIndexService Fused Sync AgentEvent PR20 Brief

Canonical deliberation: `docs/fusion/deliberation/search_index_fused_sync_agent_event_pr20_deliberation_2026_05_02.md`.

Status: implemented and verified after PR0. The sync API / `@MainActor`
recorder boundary is solved by `AgentToolProvenanceSyncRecorder`; PR20 proceeds
without actor hops or fire-and-forget work.
