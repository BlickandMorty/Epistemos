---
role: codex-red-team-fallback
slice: search-index-service-fused-sync-agent-event-pr20
brief: docs/fusion/deliberation/search_index_fused_sync_agent_event_pr20_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 2
p0_attacks: 0
p1_attacks: 2
p2_attacks: 0
p3_attacks: 0
verdict: brief-blocked
usefulness: +1
usefulness_reason: Claude CLI red-team processes produced no output; Codex fallback confirms direct PR20 code is unsafe without an enabling recorder design.
---

## Attacks

### A1 - Direct sync instrumentation cannot call the current recorder safely [P1]

**Surface:** `Epistemos/Sync/SearchIndexService.swift:563`, `Epistemos/Engine/AgentToolProvenanceRecorder.swift:3`.

**Attack:** The candidate PR20 patch would need to emit lifecycle rows from `nonisolated public func fusedSearch(...)`, but the canonical recorder is `@MainActor`. A direct call is not available from this synchronous nonisolated method, and bridging with fire-and-forget `Task`, `Task.detached`, `DispatchQueue.main.sync`, or `MainActor.assumeIsolated` would violate the provenance contract.

**Evidence:** `SearchIndexService.fusedSearch` is nonisolated/synchronous; `AgentToolProvenanceRecorder` is `@MainActor`.

**Mitigation proposed:** Block direct sync fused-search instrumentation. Open a separate enabling slice for a sync-safe shared recorder/event-builder, or keep `fusedSearchAsync` as the provenance-bearing fused-search rail.

### A2 - Preserving sync API shape prevents a narrow one-file implementation [P1]

**Surface:** `Epistemos/Sync/VaultSyncService.swift:2309`, `Epistemos/Engine/QueryRuntime.swift:289`, `EpistemosTests/SearchIndexServiceFusionTests.swift:582`.

**Attack:** Removing `nonisolated` or making `fusedSearch` async would force production caller changes in VaultSyncService and QueryRuntime, exceeding the PR20 scope and touching dirty/runtime surfaces. Duplicating recorder sequence/privacy logic inside SearchIndexService would also violate the shared-provenance pattern.

**Evidence:** Existing tests explicitly assert sync `fusedSearch` remains uninstrumented after PR19.

**Mitigation proposed:** Treat PR20 as blocked before code. If sync provenance remains desired, first build a small shared provenance construction layer with tests proving all existing AgentEvent emitters still preserve run sequence, lower-snake-case JSON, bounded payloads, and no secret leakage.

## Brief Verdict

Do not ship a Kimi/code order for direct PR20 instrumentation. The smallest safe next action is to either create an enabling recorder-safety slice or move to the next buildable master-plan slice. Because the user wants autonomous progress and the PR20 blocker is architectural rather than a small implementation issue, Codex should move to the next safe slice now and leave PR20 documented as blocked.
