---
role: codex-red-team
slice: search-index-service-fused-sync-agent-event-pr20
brief: docs/fusion/deliberation/search_index_fused_sync_agent_event_pr20_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 2
p0_attacks: 0
p1_attacks: 0
p2_attacks: 2
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: PR0 removed the P1 recorder-isolation blocker; remaining attacks are testable implementation guardrails.
---

## Attacks

### A1 - Sync instrumentation must not duplicate async secret filtering [P2]
**Surface:** `Epistemos/Sync/SearchIndexService.swift`.
**Attack:** PR20 is close to PR19 and could copy async helper logic while accidentally changing bounded fields. The sync path must persist counts, profiles, hit count, elapsed time, and closed failure class only.
**Evidence:** `MASTER_RESEARCH_INDEX_2026_05_02.md §2`; `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7.
**Mitigation proposed:** Add focused sync assertions for no query text, sanitized query, ids, snippets, scores, SQL, localized descriptions, or scalar weights in persisted AgentEvents.

### A2 - Sync path must stay direct and nonisolated [P2]
**Surface:** `SearchIndexService.fusedSearch(...)`.
**Attack:** A tempting patch could use the main-actor recorder, fire-and-forget work, or change the sync method shape. That would reintroduce the exact PR20 blocker PR0 solved.
**Evidence:** `AgentToolProvenanceSyncRecorder` exists specifically for synchronous callers.
**Mitigation proposed:** Source guards must require the sync recorder in the sync body and forbid `Task`, `Task.detached`, `DispatchQueue.main.sync`, and `MainActor.assumeIsolated`.

## Brief Verdict

Ship the revised PR20 brief. No P0/P1 blocker remains after PR0. Keep implementation to `SearchIndexService.swift`, focused tests, and docs.
