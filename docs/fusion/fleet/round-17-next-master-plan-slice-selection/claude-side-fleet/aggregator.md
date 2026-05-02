# round-17-next-master-plan-slice-selection

## recommended_slice
**Card 7 PR18 — `ShadowSearchService.search(text:domain:limit:)` AgentEvent provenance.** A pure-Swift, additive instrumentation of the only Halo/ambient-recall backend chokepoint that is *explicitly* still not covered by Card 7's AgentEvent ladder. PR16/PR17 just closed InstantRecall sync + async; ShadowSearch is the symmetric sibling those PRs deliberately fenced off ("Source and behavior stay away from ... ShadowSearch ...").

## why_now
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` lines 678–685 list "AgentEvent emission beyond ... InstantRecall async recall search" as still-open. The next named, code-safe extension along the same rail is the Halo backend search service. ContextualShadows V0 is Wired+Reachable+Visible (lines 888–896); the Halo V0 Shadow backend route is already code-closed. ShadowSearchService is therefore a **live, user-reachable retrieval chokepoint with no provenance row today**.
- Card 7 has shipped 17 PRs of identical shape (additive, sanitized, surface-scoped, single Swift file, focused tests). PR16/PR17 deliberation templates (`docs/fusion/deliberation/instant_recall_async_agent_event_pr17_deliberation_2026_05_02.md`) translate to ShadowSearch with cosmetic edits.
- ShadowSearchService is **a single Swift actor with a single user-callable async method** (`Epistemos/Engine/ShadowSearchService.swift:31`). It is consumed by `HaloController`, `ContextualShadowsState`, and `AppBootstrap`. Instrumenting at the service captures all V0 + V1 consumers with one PR; instrumenting at consumers would multiply the PR count and risk hot-path edits in HaloController (V1 budget <1 ms MainActor work per recall update).
- Substrate spine doctrine (`MASTER_RESEARCH_INDEX_2026_05_02.md` §2 + §5) treats AgentEvent + GraphEvent as parallel projection rails. Closing AgentEvent breadth before lighting up live GraphEvent consumers preserves rail symmetry and matches the user's stated priority ordering ("provenance projection ... background retrieval, or real-vault recall proof").
- Comparison verdicts:

| Slice | Verdict | Reason |
|---|---|---|
| **AgentEvent ShadowSearch provenance (this)** | **+1** | Single Swift actor, single chokepoint, identical pattern to PR16/PR17, no protected paths, no Rust, no UI/manual test, deliberation template already exists, captures live Halo/ContextualShadows V0 + V1 backend in one PR. |
| AgentEvent — other broader runtime (ChatCoordinator beyond PR3 / CloudLLM beyond generate-stream-structured / LocalAgentLoop beyond parsed tools / AgentQueryEngine beyond backend stream / Omega beyond ReasoningLoop internal) | **0** | All future-allowed by Card 7 line 902–909, but each requires bespoke chokepoint identification and a fresh boundary argument — none is as obviously "the next named open item" as ShadowSearch. Save for follow-up. |
| Live GraphEvent consumer projection beyond Halo ribbon | **0** | Card 8 forbidden write set explicitly bans `Epistemos/Views/Graph/**`, `Epistemos/Graph/**`, `graph-engine/**`. First non-Halo live consumer crosses that fence and trips Card 8 stop trigger ("live projection slice requires protected graph/editor/Rust files not named by its gate"). Useful eventually; not safest next. |
| OpLog production visibility / mutating rollback-repair | **0/-1** | "Production visibility ... beyond read-only" is precisely what Card 6's stop trigger fences. Mutating repair would have to engage §0 H8 open gaps (missing `prev_hash` BLAKE3 column, no `journal_mode=WAL` + `F_FULLFSYNC`) before any Swift surface. Wrong shape for an autonomous code-safe slice. |
| Sovereign Gate follow-through | **0** | PR1–PR8 covered the high-value confirmation surfaces. Remaining work is generated UniFFI requirement transport (forbidden by Card 9 unless a generated-transport gate names exact files) or Pro/Research Secure Enclave (out of Core scope). Smaller dialog migrations exist but are low-leverage compared to closing a live retrieval chokepoint. |
| R15 remaining specialized baselines | **0** | Live MLX tok/s under thermal soak + true Rust callback-loop export are the two open R15 items, both runtime/manual. R15 is benchmark-only and intersects forbidden hot paths (graph-engine, BoltFFI, MLX) for any production-touching gate. |
| R16 / Halo runtime/manual closure | **−1** | User flow against a real vault. Requires manual app testing, which the side-fleet brief explicitly excludes. |

## allowed_write_set
- `Epistemos/Engine/ShadowSearchService.swift` — additive recorder injection + lifecycle emission inside `search(text:domain:limit:)` only. Mirror PR17's actor-isolated emission shape: capture canonical `shadow-search-...` run id and `shadow-search:N` tool call id at entry; emit `requested` → `started` → `completed`/`failed` rows. The existing `do { try client.search ... } catch { return [] }` contract must remain byte-identical (return `[]` on error, log warning); the only addition is a `failed` AgentEvent row in the catch block before returning `[]`.
- `Epistemos/Engine/AgentProvenanceRecorder.swift` (or whichever shared recorder PR16/PR17 use) — additive constructor wiring or no-op; do not introduce a new recorder type.
- `EpistemosTests/InstantRecall...Tests.swift` style — new focused Swift Testing file, e.g. `EpistemosTests/ShadowSearchProvenanceTests.swift`, or extension of the nearest sibling provenance suite. Use the EventStore-backed pattern from `CognitiveSubstrateTests.swift` so reads use `EventStore.agentEvents(runID:limit:)`.
- `docs/fusion/deliberation/shadow_search_agent_event_pr18_deliberation_2026_05_02.md` (new file).
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 status block — add PR18 closure paragraph + tests/logs entries.
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` — append PR18 to the closed list and remove the matching open-item phrase.

## forbidden_write_set
- `agent_core/**`, `epistemos-shadow/**`, `omega-mcp/**`, `graph-engine/**`, `syntax-core/**` (any Rust crate)
- Generated UniFFI Swift / generated headers / generated libraries / Xcode project files / entitlements / DerivedData / `.xcresult`
- `Epistemos/Views/Notes/ProseEditor*.swift`, `Epistemos/Views/Notes/ProseTextView2.swift` (protected editor)
- `Epistemos/Views/Graph/MetalGraphView.swift`, `Epistemos/Views/Graph/HologramController.swift`, `Epistemos/Graph/**` (protected graph)
- `Epistemos/Engine/HaloController.swift`, `Epistemos/Engine/HaloEditorBridge.swift`, `Epistemos/State/ContextualShadowsState.swift`, `Epistemos/Views/Halo/**` — Halo hot-path code stays untouched; instrumentation lives at the service boundary, not the consumers. (HaloController is allowed read-only as evidence reference, not an edit target.)
- `Epistemos/Engine/ShadowFFIClient.swift`, `Epistemos/Engine/RustShadowFFIClient.swift` (FFI client surface)
- `Epistemos/State/EventStore.swift` schema — use existing `saveAgentEvent` / `agentEvents` API; no new column or table
- `Epistemos/Models/AgentProvenanceEvent.swift` — use existing typed payload; no kind/field additions unless a new gate names them
- Approval / routing / UI / streaming / Halo state-machine semantics — instrumentation is **additive only**. Behavior of `search(...)` (return empty on FFI error, no throw) and `searchOrThrow(...)` / `stats()` (untouched) must remain byte-identical.
- AgentEvent → OpLog / GraphEvent / Halo / Theater / ReplayBundle projection (Card 7 implementation contract)
- Persisting query text, hit body text, snippets, vault paths, source text, document ids, embeddings, raw FFI payloads, FFI error message strings (PR16/PR17 privacy invariant — translate FFI errors to bounded class names only)
- Branch operations / commits / stashes / staging
- `searchOrThrow(...)` and `stats()` — out of scope for PR18; if either needs provenance later, write a separate gate

## red_test_shape
- **Red gate**: failing focused test that calls `ShadowSearchService.search(text:domain:limit:)` against a stub FFI client and asserts `EventStore.shared.agentEvents(runID:limit:)` returns `[]` for any `shadow-search-...` run id. Captures pre-instrumentation absence. Log to `/tmp/epistemos-shadow-search-agent-event-pr18-red-20260502.log`.
- **Green gate**: focused Swift Testing suite proving:
  - **Lifecycle**: one `requested` + one `started` + exactly one terminal (`completed` or `failed`) row per call. Run id matches `shadow-search-...` pattern; tool call id matches `shadow-search:N` per-call sequence; actor metadata = `shadow-search-service`; surface metadata = `ambient-recall-shadow` (or matching V1 decision wording).
  - **Sanitization**: persisted JSON contains *only* `domain` (e.g., `"notes"`/`"chats"`/`"editor"`), `limit`, `query_count` (chars), `hit_count`, `elapsed_ms`, and bounded `failure_class` on the failed path. Asserts the literal query text, hit ids, hit body, snippet, score, vault path, source text, embedding values, FFI error message, and tool-use ids are *not* present in any AgentEvent row.
  - **Behavior preservation**: when FFI client throws, the call still returns `[]` (current contract) AND emits exactly one `failed` row with bounded class — not `completed`. When FFI returns empty hits, the call emits exactly one `completed` row with `hit_count = 0`. (Match the InstantRecall PR16 zero-hit invariant.)
  - **Cancellation**: cooperative-cancel of the awaited `search(...)` task emits exactly one terminal `failed` row with `failure_class = "cancelled"` and never a stale `completed` row. Mirrors PR17 cancellation invariant.
  - **No double-counting**: a single user call yields exactly one `requested`/`started`/terminal triple, even when InstantRecall fallback or ContextualShadows V0 also runs in the same recall cycle.
- **Source guards**:
  - Grep that no new `LocalAuthentication`, `LAContext`, `OpLog`, `GraphEvent`, `MetalGraphView`, `HologramController`, `agent_core`, `epistemos-shadow`, generated UniFFI, generated header, or protected-editor symbol appears in the diff.
  - Grep that `Epistemos/Engine/ShadowSearchService.swift` is the only `Engine/` file modified, that `Epistemos/State/EventStore.swift` is *not* modified, and that no `Epistemos/Views/**` file is modified.
  - Grep that `searchOrThrow(...)` and `stats()` bodies are byte-identical to pre-PR (no recorder leakage).
- **Build**: `xcodebuild -scheme Epistemos -destination 'platform=macOS' build-for-testing` to `/tmp/epistemos-shadow-search-agent-event-pr18-build-20260502.log`. Focused green to `/tmp/epistemos-shadow-search-agent-event-pr18-green-20260502.log`.
- `git diff --check` + protected-path name-only diff scan.

## likely_implementation_shape
- **Recorder injection**: pass an existing `AgentProvenanceRecorder`-shaped seam (whatever PR16/PR17 use; likely an injected closure or singleton accessor on `EventStore.shared`) into `ShadowSearchService.init(client:recorder:)`, defaulted to the production EventStore-backed recorder so existing call sites in `AppBootstrap` need no change. If PR17 used a freestanding helper, reuse that — do **not** introduce a new recorder type.
- **Run-id namespace**: `shadow-search-\(uuid)` per public call; tool call id `shadow-search:\(seq)` where seq is a per-actor monotonic counter. Same shape as `instant-recall-search:N` and `instant-recall-search-async:N`.
- **Inside `search(text:domain:limit:)`**:
  1. At entry: emit `requested` with sanitized metadata (`domain` enum tag, `limit`, `query_count = text.count`, `surface = "ambient-recall-shadow"`, `actor = "shadow-search-service"`). Skip emission entirely on invalid inputs (empty text after trim, non-positive limit) to mirror PR16's "valid call only" invariant.
  2. Immediately after: emit `started`.
  3. Wrap the existing `try client.search(...)` in a measurement block; on success emit `completed` with `hit_count`, `elapsed_ms`. On catch emit `failed` with a bounded `failure_class` (e.g., `ffi_error`, `backend_unavailable`, `cancelled`) — *not* the `String(describing: error)` text, since that is logged but not persisted.
  4. Preserve the current `return []` on error contract.
- **Cancellation handling**: wrap awaited body so a `CancellationError` (cooperative cancel up the call stack) emits the cancelled terminal row, mirroring PR17.
- **Tests**: extend `CognitiveSubstrateTests.swift` for the EventStore-backed assertions (matches PR16/PR17 placement) or create a dedicated `ShadowSearchProvenanceTests.swift` mirroring `InstantRecallAsync*` test layout. Use a stub `ShadowFFIClient` that returns deterministic hits and a faulted variant that throws.
- **Doc updates**: append PR18 status paragraph to Card 7 (between PR17 and the final "naming note") and tick the Card 7 closed list / UNIFIED_SUBSTRATE Bottom Line.

## risks_and_p0_stop_triggers
**P0 stop triggers (must abort if any of these come up):**
1. Implementation needs to change `ShadowSearchService.search(...)` return contract (e.g., propagate the FFI error instead of swallowing it) — that's a behavior change, not instrumentation.
2. Implementation needs to edit `HaloController.swift`, `HaloEditorBridge.swift`, `ContextualShadowsState.swift`, `Epistemos/Views/Halo/**`, or `RustShadowFFIClient.swift` to make the recorder reachable. The recorder must be injectable via the same shape PR16/PR17 used; otherwise stop and escalate.
3. Persistence requires touching `agent_events` schema or `Epistemos/Models/AgentProvenanceEvent.swift` (new kind, new column, new field) — schema is fenced by Card 7 implementation contract.
4. Recorder calls measurably regress Halo V0/V1 hot-path budget (<1 ms MainActor work per recall update; <25 ms end-to-end recall latency budget per `MASTER_RESEARCH_INDEX_2026_05_02.md` §5). Persistence is best-effort and must not block the actor; if it does, stop and rework.
5. Privacy regression — any test fails the "no query text / no hit body / no FFI error string" invariants.
6. Implementation tries to project AgentEvents into OpLog / GraphEvent / Halo / Theater / ReplayBundle (Card 7 stop trigger).
7. Implementation tries to instrument `searchOrThrow(...)` or `stats()` — out of scope for PR18.
8. Approval, routing, hot-path control flow changes anywhere — Card 7 implementation contract violation.

**P1 risks (manageable but watch):**
1. **Actor isolation friction**: `ShadowSearchService` is an actor; `EventStore.saveAgentEvent` is `nonisolated`. Calling the recorder from inside the actor must not introduce reentrancy or block the cooperative thread pool. Best practice from PR17: emit via `Task.detached` or a `nonisolated` recorder wrapper, identical to InstantRecall async. Mirror that exactly.
2. **Run-id collision** with InstantRecall fallback when InstantRecall calls down to ShadowSearch — must namespace under `shadow-search-...` so audit consumers can disambiguate from `instant-recall-...` and `instant-recall-async-...`. Test must prove no run-id reuse across services.
3. **Counter discipline**: per-actor monotonic `shadow-search:N` counter must be reset/scoped per service instance, not per-call, to match PR16/PR17 semantics.
4. **Cancellation paths** — `async` actor methods can be cancelled cooperatively; one-and-only-one terminal event must emit even if the awaited FFI call resolves after cancel.
5. **FFI error class mapping** — current code logs `String(describing: error)` and returns `[]`. The persisted `failure_class` must be a bounded enum/string set that excludes user content. Provide an explicit allowlist (e.g., `ffi_error`, `backend_unavailable`, `cancelled`, `unknown`) and assert in tests.
6. **Halo / ContextualShadows hot-path coupling** — both V0 production state and V1 Halo controller call `search(...)` at every meaningful keystroke window. If recorder cost is non-trivial per call, p99 budget breaks. Mitigation: persistence is fire-and-forget, bounded JSON only, no synchronous SQLite blocking on the actor thread.

## usefulness
**+1.** This is the cleanest narrow next slice in the AgentEvent rail: a single Swift actor file, a single user-reachable Halo retrieval chokepoint, identical pattern and deliberation template to PR16/PR17, no protected-path edits, no Rust, no manual UI testing, and explicit existing exclusion-by-name in Card 7 PR16/PR17 forbidden boundaries. It closes a live blind spot (Halo V0 backend has no provenance row today despite being W+R+V) before any GraphEvent live consumer or OpLog repair work demands a fresh protected-path gate.

CLAUDE-RETURN: role=SIDE-FLEET | slice=round-17-next-master-plan-slice-selection | round=17 | artifact=docs/fusion/fleet/round-17-next-master-plan-slice-selection/claude-side-fleet/aggregator.md | recommended=card-7-pr18-shadow-search-agent-event-provenance | usefulness=+1 | p0=8 | p1=6
