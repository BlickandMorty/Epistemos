---
role: claude-red-team
slice: shadow-search-agent-event-pr18
brief: docs/fusion/deliberation/shadow_search_agent_event_pr18_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 10
p0_attacks: 3
p1_attacks: 4
p2_attacks: 3
p3_attacks: 0
verdict: brief-revise
usefulness: +1
usefulness_reason: Brief is correctly tier-scoped and protected-path-tight, but must pin actor recorder cost, cancellation, closed failure classes, and PR17-parity guard tests.
---

## Attacks

### A1 - Actor to MainActor recorder hop can reintroduce ambient hot-path cost [P0]
**Surface:** Implementation Contract, `Epistemos/Engine/ShadowSearchService.swift`
**Attack:** `ShadowSearchService` exists to keep Shadow FFI off MainActor, while `AgentToolProvenanceRecorder` is `@MainActor`. A compliant implementation could add three MainActor hops per ambient search without any budget/test. The brief must commit to a bounded hop shape.
**Evidence:** `Epistemos/Engine/ShadowSearchService.swift:6`; `Epistemos/Engine/AgentToolProvenanceRecorder.swift:3`; `MASTER_RESEARCH_INDEX_2026_05_02.md §5`.
**Mitigation proposed:** Pin the implementation to discrete recorder awaits that preserve lifecycle ordering and add acceptance coverage proving the search still returns through the actor path without UI/Halo edits. Do not introduce schema, singleton, or new sink abstractions in this slice.

### A2 - Cancellation classification is unspecified [P0]
**Surface:** Implementation Contract and Acceptance
**Attack:** PR17 established cancellation as terminal `toolCallFailed` with `failure_class = "cancelled"` and `errorMessage = "cancelled"`. PR18's brief only says "cancellation" and leaves completed-vs-failed and slug choice ambiguous.
**Evidence:** `Epistemos/KnowledgeFusion/InstantRecallService.swift:541`; `EpistemosTests/InstantRecallTests.swift:471`.
**Mitigation proposed:** Require cancelled ShadowSearch calls to emit `toolCallFailed`, `status = .failed`, `failure_class = "cancelled"`, and `errorMessage = "cancelled"`.

### A3 - Failure-class set is bounded but not enumerated [P0]
**Surface:** Implementation Contract
**Attack:** `ShadowFFIError` has six discriminants, but the brief does not enumerate the persisted slugs. Without a closed set, privacy and analytics tests cannot prove error text is sanitized.
**Evidence:** `Epistemos/Engine/ShadowFFIClient.swift:24`.
**Mitigation proposed:** Declare the only allowed slugs: `invalid_input`, `not_found`, `io_failure`, `backend_failure`, `rust_panic`, `unknown_code`, `cancelled`, and `unknown_error`. Require `errorMessage` to equal the slug.

### A4 - Default recorder can write to production EventStore in existing tests [P1]
**Surface:** Implementation Contract and `ShadowServicesTests`
**Attack:** Existing ShadowSearchService tests construct the service with only `client:`. If the default recorder is production-backed, tests may persist AgentEvents to `EventStore.shared`.
**Evidence:** `Epistemos/Engine/AgentToolProvenanceRecorder.swift:17`; `EpistemosTests/ShadowServicesTests.swift:105`.
**Mitigation proposed:** Update all ShadowSearchService tests in `ShadowServicesTests.swift` to inject an in-memory recorder sink.

### A5 - Tool-call ID ownership across service instances is undefined [P1]
**Surface:** Implementation Contract
**Attack:** The brief says `shadow-search:<N>` but does not say whether the counter is per service instance or global. Multiple instances could each emit `shadow-search:1`; downstream joins must use run ID, not tool ID alone.
**Evidence:** `Epistemos/Engine/ShadowSearchService.swift:19`; `EpistemosTests/InstantRecallTests.swift:443`.
**Mitigation proposed:** Declare per-instance monotonic IDs starting at 1, with UUID run IDs as the disambiguating join key. Test per-instance behavior.

### A6 - Privacy grep misses body/path/errorMessage channels [P1]
**Surface:** Failure-proof guardrails
**Attack:** The denylist misses `body`, raw `id`, `path`, `vault`, and `errorMessage`; it also cannot prove result payload keys are whitelisted.
**Evidence:** `Epistemos/Engine/ShadowFFIClient.swift:85`; `Epistemos/Engine/AgentToolProvenanceRecorder.swift:38`.
**Mitigation proposed:** Add positive whitelist tests for arguments/result JSON keys, extend denylist checks, and assert `errorMessage` belongs to the closed failure-class set.

### A7 - Acceptance lacks PR16/PR17 parity tests [P1]
**Surface:** Acceptance
**Attack:** PR17 tests pin result key whitelist, failure-class membership, error-message slug equality, and counter behavior. PR18's acceptance is coarser and could ship a weaker audit floor.
**Evidence:** `EpistemosTests/InstantRecallTests.swift:381`; `EpistemosTests/InstantRecallTests.swift:443`.
**Mitigation proposed:** Add tests for result payload key whitelist, closed failure classes, errorMessage slug equality, and monotonic per-instance tool-call IDs.

### A8 - Invalid-input edge cases are underspecified [P2]
**Surface:** Implementation Contract
**Attack:** Empty string, whitespace-only text, `limit = 0`, and negative limit can diverge if not specified. Halo may naturally pass empty text during state transitions.
**Evidence:** Brief implementation contract; `Epistemos/Engine/ShadowFFIClient.swift:170`.
**Mitigation proposed:** Declare invalid calls (`text` trims empty or `limit <= 0`) return `[]` and emit zero AgentEvents. Test all four cases.

### A9 - `searchOrThrow` remains unrecorded without an explicit asymmetry note [P2]
**Surface:** Implementation Contract
**Attack:** Leaving `searchOrThrow` unrecorded is defensible, but the brief should say it is intentionally out of scope because it is a developer-panel/error surface and may expose raw error detail.
**Evidence:** `Epistemos/Engine/ShadowSearchService.swift:42`.
**Mitigation proposed:** Add an explicit out-of-scope note and a source guard that its body remains unchanged.

### A10 - New `surface` label must be pinned in state docs [P2]
**Surface:** Implementation Contract and doc updates
**Attack:** PR18 introduces a new surface label but the brief does not name it. Future projection filters need the surface string to be exact.
**Evidence:** Brief implementation contract; `MASTER_RESEARCH_INDEX_2026_05_02.md §2`.
**Mitigation proposed:** Pin `surface = "shadow_search"` and update current-state/workcard docs with that exact label.

## Brief verdict

The slice is sound and should proceed after brief revision. The P0/P1 fixes are: pin the recorder hop policy, pin cancellation as failed with `cancelled`, enumerate the closed failure-class set, inject in-memory recorder sinks in all ShadowSearch tests, declare per-instance tool-call counters, strengthen privacy/result whitelist tests, and explicitly keep `searchOrThrow`/`stats` untouched.

CLAUDE-RETURN: role=RED-TEAM | slice=shadow-search-agent-event-pr18 | round=18 | artifact=docs/fusion/fleet/shadow-search-agent-event-pr18/claude-red-team/attacks.md | usefulness=+1 | p0=3 | p1=4
