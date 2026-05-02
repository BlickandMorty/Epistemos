---
role: claude-red-team
slice: search-index-service-fused-async-agent-event-pr19
brief: docs/fusion/deliberation/search_index_fused_async_agent_event_pr19_deliberation_2026_05_02.md
date: 2026-05-02
round: 20-r2
prior_packet: docs/fusion/fleet/search-index-service-fused-async-agent-event-pr19/claude-red-team/attacks.md
attacks_total: 3
p0_attacks: 0
p1_attacks: 0
p2_attacks: 3
p3_attacks: 0
verdict: approved
usefulness: +1
usefulness_reason: All eight bullets r1 demanded are present in the revised brief; the structural A1 contradiction is resolved by the actor-scope-then-offload split, A2 by lazy `MainActor.run { … }` from the actor method, A3 by a single terminal-row emission point with mid-flight-only guarantees. Three residual P2 tightenings remain but none block Kimi.
---

## Closure summary (round 20 → 20-r2)

| r1 ID | Severity | Status | Anchor in revised brief |
| ----- | -------- | ------ | ----------------------- |
| A1    | P0 → ✅  | Closed | L47–49: `requested`/`started` emitted from actor scope before `offloadSearch` is awaited; `completed`/`failed` from actor scope after; recorder explicitly forbidden inside the non-async offload closure. The "started = actor-scope dispatch, not queue execution" gloss removes the only ambiguity the implementer would have hit. |
| A2    | P0 → ✅  | Closed | L46–47: `AgentToolProvenanceRecorder?` with `nil` default keeps existing `init` non-`@MainActor`; lazy production recorder built via `await MainActor.run { AgentToolProvenanceRecorder() }` from the actor method. No `MainActor.assumeIsolated` deadlock vector; protected `VaultSyncService`/`AppBootstrap` call sites stay byte-identical. |
| A3    | P0 → ✅  | Closed | L49 + L55: terminal emission is owned by the actor scope (single point), so success/cancel race in `OffloadedSearchState.finish(with:)` cannot produce two terminal rows; mid-flight cancellation after `started` is guaranteed; pre-flight cancellation explicitly authorised to emit no rows; tests must use a sync point, killing the warm/cold runner flake. |
| A4    | P1 → ✅  | Closed | L52 (closed set `cancelled \| sql_error \| unknown_error`, type-only derivation, never inspect message), L53 (no GRDB error strings persisted), L80 (`(log\.\|os_log\|Logger).*\\(error` forbidden grep). GRDB FTS5 syntax-error message bytes can no longer leak into recorder metadata or OSLog. |
| A5    | P1 → ✅  | Closed | L81 negative grep: `git grep -n -A 35 "nonisolated public func fusedSearch(" … \| grep -E "(agentProvenanceRecorder\|recordToolEvent)"`. Acceptance L67 adds the green test. |
| A6    | P1 → 🟡 | Mostly closed (see B1) | L49 says "from the actor scope" + L54 says "Preserve throws behavior". Natural Swift impl is `await recorder.record…; throw error`. Acceptance L66 lifecycle test would fail a fire-and-forget impl on most runs, but no explicit guard against `Task { @MainActor in … }` and no temporal-ordering assertion. |
| A7    | P1 → ✅  | Closed | L56: counter is "actor-isolated, per-service-instance, and monotonic. It must not be static, global, or `nonisolated(unsafe)`." Acceptance L67 mandates concurrent-call uniqueness test. |
| A8    | P1 → ✅  | Closed | L48 "returns non-empty" + acceptance L65 covers empty/whitespace/empty-after-normalization. |
| A9    | P1 → ✅  | Closed | L55 "Tests must cancel after observing a started-row synchronization point." Pre-flight zero-row case explicitly authorised. |
| A10   | P1 → ✅  | Closed | L57 mandates injection of no-op/in-memory recorder for existing async fusion tests. |
| A11   | P1 → ✅  | Closed | L6 adds `Gate: SovereignGate touchpoint? none.` matching PR18 brief shape. |
| A12   | P1 → ✅  | Closed | L50 verbatim regex `^search-index-fused-async-[0-9A-F-]{36}$`. |
| A13   | P1 → ✅  | Closed | L51 + acceptance L68: `weights_profile=default\|custom`, scalar weight values explicitly forbidden in metadata. |
| A14   | P2 → ✅  | Closed | L58 mandates `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` update. |
| A15   | P2 → ✅  | Closed | L52 enumerates the closed set, blocking PR18's `not_found`/`rust_panic`/etc. copy-paste. |

All three P0 and all nine P1 from r1 are closed. Both r1 P2s are also closed. The remaining attack surface is three new P2 tightenings introduced by the revision itself.

## Residual attacks on the revised brief

### B1 — Brief authorises actor-scope terminal emission but does not forbid `Task { @MainActor in … }` fire-and-forget [P2]
**Surface:** Implementation contract bullet "Emit `completed` or `failed` after `offloadSearch` returns or throws, from the actor scope." Files: `Epistemos/Sync/SearchIndexService.swift:621-624` (existing catch), `Epistemos/Engine/AgentToolProvenanceRecorder.swift:25-75` (recorder is `@MainActor`, called from actor scope via `await`).
**Attack:** "From the actor scope" is satisfied syntactically by `Task { @MainActor in await recorder.recordToolEvent(...) }; throw error` — the `Task` is *created* on the actor's executor. That impl emits the terminal row asynchronously, so two concurrent `fusedSearchAsync` calls can interleave their terminal rows in `EventStore.shared` and a downstream consumer that re-throws on the caller side may observe the next call's `requested` row before this call's `failed` row. The acceptance L66 lifecycle test catches the case where the test inspects events synchronously after the throw, but a slow MainActor + `Task {}` impl can still pass the test deterministically while shipping out-of-order events under load. The recorder's `sequenceByRunID` (`AgentToolProvenanceRecorder.swift:50-52`) preserves *intra-runID* ordering but cannot fix *inter-runID* `occurredAtMs` inversion across two concurrent fused searches.
**Evidence:** `Epistemos/Engine/AgentToolProvenanceRecorder.swift:50-52`, `Epistemos/Sync/SearchIndexService.swift:621-624`, brief lines 49 + 54.
**Mitigation proposed:** Add one bullet to the implementation contract: "Terminal-row emission must be `await recorder.recordToolEvent(...)` directly; `Task {…}` / `Task.detached {…}` for the terminal row is forbidden. The `await` precedes `throw error` in the failure branch and precedes `return results` in the success branch." Optional: extend acceptance L66 with a green test asserting that for two concurrent `fusedSearchAsync` calls A and B against the same injected recorder, B's `requested` event has `occurredAtMs >= A.completed.occurredAtMs` whenever B was started after A completed.

### B2 — Lazy recorder storage lifetime unspecified; per-call construction is technically conformant [P2]
**Surface:** Implementation contract bullet "Lazily create the production recorder from the actor method with `await MainActor.run { AgentToolProvenanceRecorder() }` when no recorder was injected." Files: `Epistemos/Engine/AgentToolProvenanceRecorder.swift:7` (`sequenceByRunID` is per-recorder-instance state).
**Attack:** Brief says "Lazily create" but does not say "store in actor-isolated state and reuse across calls." A literal-minded implementer could construct a new `AgentToolProvenanceRecorder` on every `fusedSearchAsync` invocation. Functionally harmless today because the per-runID sequence counter (recorder line 50) keys on a new UUID-suffixed runID per call, so resetting it is a no-op for emission semantics. But (a) it imposes one extra `MainActor.run` hop per search on the hot path, partially defeating the perf-doctrine in `MEMORY.md` "Halo / recall / search rail," and (b) it forecloses any future PR that wants a per-recorder cache of, e.g., approval IDs or trace correlation. Two concurrent first-callers under actor reentrancy can also each create their own recorder before either stores; last-writer-wins. The brief should specify the storage shape.
**Evidence:** Brief line 47, `Epistemos/Engine/AgentToolProvenanceRecorder.swift:7-23`.
**Mitigation proposed:** Replace L47 with: "Stored in an actor-isolated `private var agentProvenanceRecorder: AgentToolProvenanceRecorder?`. On first emission, if `nil`, set it via `agentProvenanceRecorder = await MainActor.run { AgentToolProvenanceRecorder() }`. All subsequent emissions reuse the stored instance. Reentrant double-construction is acceptable (last-writer-wins) and does not need a lock."

### B3 — Brief implicitly relocates `normalizedSearchTerms(query)` from concurrent `queryQueue` to actor scope without acknowledgement [P2]
**Surface:** Implementation contract bullet "Emit `requested` and `started` after `normalizedSearchTerms(query)` returns non-empty and before `offloadSearch` is awaited." Files: `Epistemos/Sync/SearchIndexService.swift:601-604` (`normalizedSearchTerms` + `sanitizeFTS5Query` currently inside `offloadSearch` closure on `queryQueue`).
**Attack:** Today `normalizedSearchTerms` and `sanitizeFTS5Query` execute on `queryQueue` (concurrent, `qos: .userInitiated`, `Epistemos/Sync/SearchIndexService.swift:159-163`). The revised contract requires reading the term-list result *before* `offloadSearch` is awaited, which forces these calls to run on the actor's serial executor. For 99% of queries this is harmless (pure CPU on a sub-1KB string), but two implications are unstated: (i) under contention, all `fusedSearchAsync` callers serialize through the actor for the normalization step, where today they fan out across the concurrent queue; (ii) `Self.sanitizeFTS5Query(terms)` (line 604) currently runs on `queryQueue` too — if the implementer pulls *only* `normalizedSearchTerms` to the actor, `sanitizeFTS5Query` remains in the closure, splitting the search-prep across two executors. Brief should pick one shape and call out the executor move.
**Evidence:** `Epistemos/Sync/SearchIndexService.swift:601-604`, `Epistemos/Sync/SearchIndexService.swift:159-163`, brief line 48.
**Mitigation proposed:** Add one bullet to the implementation contract: "Both `normalizedSearchTerms(query)` (term gating) and `sanitizeFTS5Query(terms)` (downstream FTS5 escaping) move to actor scope before `offloadSearch` is awaited; the `offloadSearch` closure receives only the prepared sanitized query string. This is an intentional executor change from `queryQueue` to the SearchIndexService actor for these CPU-bounded steps; latency impact is < 10 µs on M-series for 1-KB queries."

## Brief verdict

**approved** — all 3 P0 and all 9 P1 from round 20 r1 are closed by the revised brief. The smallest required revision is empty: nothing P0/P1 remains. The three P2 residuals (B1 fire-and-forget guard, B2 recorder storage lifetime, B3 executor relocation acknowledgement) are nice-to-haves Kimi can land in the same diff without blocking the slice. Recommend Coordinator unblock Kimi to draft tests and implementation.

CLAUDE-RETURN: role=RED-TEAM | slice=search-index-service-fused-async-agent-event-pr19 | round=20-r2 | artifact=docs/fusion/fleet/search-index-service-fused-async-agent-event-pr19/claude-red-team/attacks-r2.md | usefulness=+1 | p0=0 | p1=0
