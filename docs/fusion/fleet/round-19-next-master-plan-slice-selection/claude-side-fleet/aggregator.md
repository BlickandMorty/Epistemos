---
role: claude-side-fleet
slice: round-19-next-master-plan-slice-selection
round: 19
date: 2026-05-02
tier: Core
authority_anchor: EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md §1 (current code + passing logs > repo authority > fusion canon)
master_plan_anchors:
  - MASTER_RESEARCH_INDEX_2026_05_02.md §2 (substrate spine — AgentEvent rail)
  - MASTER_RESEARCH_INDEX_2026_05_02.md §5 (Halo / Recall — RRF k=60 fusion is the canonical search rail)
  - MASTER_RESEARCH_INDEX_2026_05_02.md §8 (Streaming / FFI — fused_search signpost already in place)
  - MASTER_RESEARCH_INDEX_2026_05_02.md §22 (operating rule)
workcard_anchor: AGENT_BUILD_WORKCARDS_2026_05_01.md Card 7 (AgentEvent Tool Provenance)
substrate_state_anchor: UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md "Still open" (lines 686–698) + "Bottom Line" decision tree (lines 984–996)
prior_round_decision: round-17 picked PR18 ShadowSearch (sync, single Swift actor); shipped at commit 0e3fdec2 ("Record ShadowSearch provenance") on 2026-05-02
recommended_slice_slug: search-index-service-fused-async-agent-event-pr19
alternate_slice_slug: search-index-service-fused-sync-agent-event-pr19-alt
usefulness: +1
usefulness_reason: Single Swift actor, single user-reachable RRF cross-index fusion chokepoint, exact mirror of PR17 (async InstantRecall) and PR18 (ShadowSearch) shape, no protected paths, no Rust, no UI, no manual test, deliberation template already exists.
p0_stop_triggers: 8
p1_risks: 6
---

# round-19-next-master-plan-slice-selection

## recommended_slice
**Card 7 PR19 — `SearchIndexService.fusedSearchAsync(query:weights:now:)` AgentEvent provenance.** A pure-Swift, additive instrumentation of the next named user-reachable retrieval chokepoint after PR18 ShadowSearch: the canonical RRF (Reciprocal Rank Fusion, k=60) cross-index fusion search executed against the Vault's FTS5 derivative index. The async sibling is chosen first because it is the exact actor-isolated `await`-recorder shape PR17 (async InstantRecall) and PR18 (ShadowSearch) already proved; the synchronous `nonisolated public func fusedSearch(...)` becomes PR20 (the sync→`Task { @MainActor in … }` fire-and-forget pattern is a separate gate decision).

## why_now

- **Named open AgentEvent surface, code-safe rail extension.** `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` lines 686–698 list "AgentEvent emission beyond ... InstantRecall async recall search" as still-open and lines 984–996 ("Bottom Line") name "remaining broader runtime AgentEvent coverage" as one of the explicit next-best targets. PR14–PR18 have closed every named per-service search/retrieval chokepoint **except** the SearchIndexService RRF fusion path. Verified by grep: `Epistemos/Sync/SearchIndexService.swift`, `VaultSyncService.swift`, and `Engine/QueryRuntime.swift` contain **zero** `AgentProvenance|saveAgentEvent` references today (Grep, 2026-05-02).
- **Live, user-reachable, no-flag-needed-to-emit chokepoint.** `SearchIndexService.fusedSearchAsync` is consumed in production today by `VaultSyncService.searchFullAsync` (line 2326) and indirectly by the global vault search rail, gated by `RRFFusionFlags.isEnabled` (env var `EPISTEMOS_RRF_FUSION_V1`; CLAUDE.md "Swift RRF Cross-Index Fusion" §). When the flag is OFF the path simply isn't exercised — provenance never lies; it never emits a row that didn't happen. Same shape as PR18 (ShadowSearch was only exercised when a per-vault Shadow backend was configured).
- **Master-plan rail symmetry.** `MASTER_RESEARCH_INDEX_2026_05_02.md` §2 + §5 treat AgentEvent + GraphEvent as parallel projection rails; closing AgentEvent breadth across the **search/retrieval** sub-rail before lighting up live GraphEvent consumer projection (Card 8 PR9+) preserves rail symmetry and matches the Bottom Line decision-tree priority ordering ("provenance projection ... background retrieval, or real-vault recall proof").
- **Identical pattern to PR17/PR18 — the deliberation template translates with cosmetic edits.** PR17 (`InstantRecallService.searchAsync`) and PR18 (`ShadowSearchService.search`) are both async actor-isolated methods using `AgentToolProvenanceRecorder` (`Epistemos/Engine/AgentToolProvenanceRecorder.swift`) injected on `@MainActor` with `await recorder.recordToolEvent(...)` from inside the actor. `SearchIndexService.fusedSearchAsync` (line 591–626) is the exact same shape: `actor SearchIndexService` + `public func fusedSearchAsync(...) async throws -> [FusedResult]` + an existing `OSSignposter.beginInterval("fused_search", ...)` + an existing `SearchFusionMetrics.shared.record(latencyMs:results:)` call site (line 619) — provenance instrumentation slots in alongside the existing metrics with no new ceremony.
- **Sync sibling deliberately deferred to PR20.** `SearchIndexService.fusedSearch(...)` (line 557) is `nonisolated public func` and synchronous. Calling a `@MainActor` recorder from a nonisolated synchronous context requires a `Task { @MainActor in recorder.recordToolEvent(...) }` fire-and-forget shape that has not yet been pioneered in the PR14–PR18 ladder. Doing it second (in PR20) keeps PR19's risk surface minimal and preserves the user's "smallest safe slice" preference.

### Comparison verdicts

| Slice | Verdict | Reason |
|---|---|---|
| **AgentEvent SearchIndexService.fusedSearchAsync (this)** | **+1** | Single Swift actor, single chokepoint, identical pattern to PR17/PR18, no protected paths, no Rust, no UI/manual test, deliberation template exists, captures live RRF fusion search reachable through `VaultSyncService.searchFullAsync` and (transitively) `QueryRuntime.fullText` in one PR. Verified pre-instrumentation absence by grep. |
| AgentEvent SearchIndexService.fusedSearch (sync, nonisolated) | **0/+1** | Same chokepoint family but the recorder dispatch is genuinely new (sync→@MainActor fire-and-forget). Better as PR20 follow-up; held as the alternate if PR19 async proves blocked. |
| AgentEvent SearchIndexService.search/searchBlocks (legacy non-fused FTS5) | **0** | Same file, multiple methods; bypassed when RRF flag is on; load-bearing only on the legacy fallback path. Lower architectural priority than the canonical RRF fusion entry. Future opt-in PR. |
| AgentEvent VaultSyncService.searchFull / searchFullAsync (higher-level wrapper) | **0/-1** | Wrapping the wrapper would double-instrument once SearchIndexService is closed (RRF call lives one stack frame deeper). Pick the deepest single chokepoint, not the call-site. Same anti-pattern as instrumenting HaloController instead of ShadowSearchService in PR18. |
| AgentEvent QueryRuntime.fullText (consumer call-site) | **0/-1** | Same double-instrument concern; QueryRuntime calls `searchIndex.fusedSearch(...)` directly. Skip. |
| AgentEvent — broader runtime (ChatCoordinator beyond PR3 / CloudLLM beyond generate-stream-structured / LocalAgentLoop beyond parsed tools / AgentQueryEngine beyond backend stream / Omega beyond ReasoningLoop internal) | **0** | All future-allowed by Card 7 lines 916–923, but each requires bespoke chokepoint identification and a fresh boundary argument. Save for follow-up after the search/retrieval sub-rail is fully closed. |
| Live GraphEvent consumer projection beyond Halo ribbon (Card 8 PR9+) | **0** | Card 8 forbidden write set still bans `Epistemos/Views/Graph/**`, `Epistemos/Graph/**`, `graph-engine/**`. First non-Halo live consumer crosses that fence and trips Card 8 stop trigger ("live projection slice requires protected graph/editor/Rust files not named by its gate"). Useful eventually; not safest next. |
| Sovereign Gate generated requirement transport | **0/-1** | Forbidden by Card 9 unless a generated-transport gate names exact files (CLAUDE.md "DO NOT" + Card 7 forbidden write set: "generated Swift/header bindings"). Tier-leakage risk from broad UniFFI churn. Out of scope for "avoid broad generated bindings." |
| Sovereign Gate Pro/Research Secure Enclave | **−1** | Pro/Research tier; user instructions "avoids App Store/pro tier policy unless clearly next." Not clearly next — Core PR1–PR8 already covers the high-value confirmation surfaces. |
| MAS/Core vs Pro symbol-separation audit | **0/-1** | App Store policy slice; explicitly deprioritized by user instructions and by `UNIFIED_SUBSTRATE_CURRENT_STATE` line 718 ("MAS/Core versus Pro capability symbol separation" — still open but a multi-file release-engineering slice, not a single chokepoint). |
| OpLog mutating rollback/repair beyond read-only | **0/-1** | Card 6 stop trigger explicitly fences "Production visibility ... beyond read-only." Mutating repair would have to engage `MASTER_RESEARCH_INDEX_2026_05_02.md` §0 H8 (missing `prev_hash` BLAKE3 column, no `journal_mode=WAL` + `F_FULLFSYNC`). Wrong shape for autonomous code-safe slice. |
| R15 remaining specialized baselines / R16 manual / Halo manual | **−1** | All require runtime/manual app testing against a real vault. Side-fleet brief explicitly excludes manual UI testing per the user's order. |

## allowed_write_set
- `Epistemos/Sync/SearchIndexService.swift` — additive recorder injection + lifecycle emission inside `fusedSearchAsync(query:weights:now:)` only (line 591–626). Mirror PR17/PR18's actor-isolated emission shape: capture canonical `search-index-fused-async-...` run id and `search-index-fused-async:N` tool call id at entry; emit `requested` → `started` → `completed`/`failed` rows around the existing `dbPool.read { ... RRFFusionQuery.execute ... }` body. The existing throw-on-error contract must remain byte-identical (still throws to the consumer; provenance just records `failed` before re-throw). The sync `fusedSearch` (line 557) is **out of scope** for PR19; defer to PR20.
- `Epistemos/Engine/AgentToolProvenanceRecorder.swift` — additive constructor wiring or no-op; do not introduce a new recorder type. Reuse the same `@MainActor final class AgentToolProvenanceRecorder` PR16/PR17/PR18 use. Inject on `@MainActor init`.
- `EpistemosTests/SearchIndexServiceFusionTests.swift` (existing — Phase-5 RRF integration suite) **or** a new focused Swift Testing file `EpistemosTests/SearchIndexFusedAsyncProvenanceTests.swift`, mirroring the `InstantRecallAsync*Tests` / `ShadowSearchProvenanceTests` shape. Use the EventStore-backed pattern from `CognitiveSubstrateTests.swift` so reads use `EventStore.agentEvents(runID:limit:)`.
- `docs/fusion/deliberation/search_index_fused_async_agent_event_pr19_deliberation_2026_05_02.md` (new file).
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 status block — append PR19 closure paragraph + tests/logs entries between the current PR18 closure paragraph and the "naming note" line.
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` — append PR19 to the closed list (Bottom Line) and remove the matching open-item phrase.

## forbidden_write_set
- `agent_core/**`, `epistemos-shadow/**`, `omega-mcp/**`, `graph-engine/**`, `syntax-core/**` (any Rust crate)
- Generated UniFFI Swift / generated headers / generated libraries / Xcode project files / entitlements / DerivedData / `.xcresult`
- `Epistemos/Views/Notes/ProseEditor*.swift`, `Epistemos/Views/Notes/ProseTextView2.swift` (protected editor)
- `Epistemos/Views/Graph/MetalGraphView.swift`, `Epistemos/Views/Graph/HologramController.swift`, `Epistemos/Graph/**` (protected graph)
- `Epistemos/Sync/RRFFusionQuery.swift` (the SQL + types layer — out of scope; PR19 is purely an emission slice around the existing call site)
- `Epistemos/Sync/VaultSyncService.swift`, `Epistemos/Engine/QueryRuntime.swift` (consumer call-sites — instrumentation lives at the SearchIndexService boundary, not the consumers; double-instrumentation is forbidden)
- `Epistemos/Sync/ReadableBlocksIndex.swift`, `RRFFusionQuery` SQL, FTS5 schema, GRDB migrations
- `Epistemos/State/EventStore.swift` schema — use existing `saveAgentEvent` / `agentEvents` API; no new column or table
- `Epistemos/Models/AgentProvenanceEvent.swift` — use existing typed payload; no `kind` / field additions unless a new gate names them
- `Epistemos/Engine/HaloController.swift`, `ShadowSearchService.swift`, `InstantRecallService.swift`, `AgentGrepService.swift`, `AgentQueryEngine.swift` (already-instrumented siblings — PR19 must not edit them)
- `Epistemos/Sync/SearchIndexService.swift::fusedSearch (sync)` body and signature (line 557–587) — defer to PR20
- `Epistemos/Sync/SearchIndexService.swift::search / searchAsync / searchBlocks / searchBlocksAsync` (lines 492–545) — out of scope; legacy non-fused FTS5 paths are a future PR family
- AgentEvent → OpLog / GraphEvent / Halo / Theater / ReplayBundle projection (Card 7 implementation contract line 945)
- Persisting query text, fused-result body text, snippets, vault paths, source text, document ids, score values, embeddings, raw RRF fusion SQL parameters, GRDB error messages (PR16/PR17/PR18 privacy invariant — translate any errors to bounded class names only)
- Branch operations / commits / stashes / staging / xcodegen
- Approval / routing / UI / streaming / Search hot-path semantics — instrumentation is **additive only**. The throw-on-error contract of `fusedSearchAsync` (line 591–626) and the existing `SearchFusionMetrics.shared.record(...)` / `recordError(...)` calls must remain byte-identical.

## red_test_shape
- **Red gate**: failing focused test that calls `SearchIndexService.fusedSearchAsync(query:)` against a file-backed `SearchIndexService` (Phase-5 fixture pattern from `EpistemosTests/SearchIndexServiceFusionTests.swift`) with the RRF flag enabled and asserts `EventStore.shared.agentEvents(runID:limit:)` returns `[]` for any `search-index-fused-async-...` run id. Captures pre-instrumentation absence. Log to `/tmp/epistemos-search-index-fused-async-agent-event-pr19-red-20260502.log`.
- **Green gate**: focused Swift Testing suite proving:
  - **Lifecycle**: one `requested` + one `started` + exactly one terminal (`completed` or `failed`) row per call. Run id matches `search-index-fused-async-...` pattern; tool call id matches `search-index-fused-async:N` per-instance sequence; actor metadata = `search-index-service` (or sibling-consistent label); surface metadata = `fused_search_async` (or matching `surface=fused_search` decision wording).
  - **Sanitization**: persisted JSON contains *only* sanitized scalars: `query_count` (chars), `term_count`, `weights_lex` / `weights_vec` / `weights_recency` (numeric), `now_ms`, `hit_count`, `elapsed_ms`, and bounded `failure_class` on the failed path. Asserts the literal query text, FTS5-sanitized query, fused result snippets, page/block ids, vault paths, source text, fusion score values, recency exp() values, and GRDB error message are *not* present in any AgentEvent row.
  - **Behavior preservation**: when GRDB throws inside `dbPool.read`, the call still throws (current contract) AND emits exactly one `failed` row with bounded class — not `completed`. The existing `SearchFusionMetrics.shared.recordError(error)` call at line 622–624 still fires before the throw. When the corpus is empty, the call emits exactly one `completed` row with `hit_count = 0`. Cooperative-cancel of the awaited `fusedSearchAsync(...)` task emits exactly one terminal `failed` row with `failure_class = "cancelled"` (mirrors PR17/PR18 cancellation invariant).
  - **No double-counting**: a single `fusedSearchAsync(...)` call yields exactly one `requested`/`started`/terminal triple, even when called from inside `VaultSyncService.searchFullAsync` (which itself is just a thin wrapper) — proves the chokepoint is the SearchIndexService method, not the wrapper.
  - **Empty/invalid input**: when `Self.normalizedSearchTerms(query)` returns empty (line 601), the early `return []` path emits NO AgentEvent rows (matches PR16/PR18 "valid call only" invariant). Provenance never lies about a search that was rejected before it ran.
  - **Sync method untouched**: a unit assertion that `SearchIndexService.fusedSearch(...)` (sync) still emits no provenance row (proves PR19 did not silently smuggle the sync sibling in).
- **Source guards**:
  - Grep that no new `LocalAuthentication`, `LAContext`, `OpLog`, `GraphEvent`, `MetalGraphView`, `HologramController`, `agent_core`, `epistemos-shadow`, `RRFFusionQuery`-SQL-edit, generated UniFFI, generated header, or protected-editor symbol appears in the diff.
  - Grep that `Epistemos/Sync/SearchIndexService.swift` is the only `Sync/` file modified, that `Epistemos/State/EventStore.swift` is *not* modified, that `Epistemos/Sync/RRFFusionQuery.swift` is *not* modified, and that no `Epistemos/Views/**` file is modified.
  - Grep that the bodies of `nonisolated public func fusedSearch(...)` (line 557–587), `nonisolated func search(...)` (line 492–504), `func searchAsync(...)` (line 505–514), `nonisolated func searchBlocks(...)` (line 516–522), and `func searchBlocksAsync(...)` (line 523–545) are byte-identical to pre-PR (no recorder leakage into out-of-scope methods).
- **Build**: `xcodebuild -scheme Epistemos -destination 'platform=macOS' build-for-testing` to `/tmp/epistemos-search-index-fused-async-agent-event-pr19-build-20260502.log`. Focused green to `/tmp/epistemos-search-index-fused-async-agent-event-pr19-green-20260502.log`.
- `git diff --check` + protected-path name-only diff scan.

## likely_implementation_shape
- **Recorder injection**: extend `SearchIndexService.init(...)` with a `@MainActor`-defaulted `agentProvenanceRecorder: AgentToolProvenanceRecorder = AgentToolProvenanceRecorder()` parameter — same shape as PR18 ShadowSearch (line 36–46). Existing call sites in `AppBootstrap` need no change because the default value satisfies the new parameter. **Do not** introduce a new recorder type. The init must hop to `@MainActor` for construction; document inline why (matches PR18 comment `path under the V1 budget (<1 ms MainActor work per recall update)`).
- **Run-id namespace**: `search-index-fused-async-\(uuid)` per public call; tool call id `search-index-fused-async:\(seq)` where `seq` is a per-actor monotonic counter (`private var fusedAsyncSearchSequence: UInt64 = 0`). Same shape as `instant-recall-search-async:N` and `shadow-search:N`.
- **Inside `fusedSearchAsync(query:weights:now:)`** (line 591–626):
  1. After the existing early `guard !terms.isEmpty else { return [] }` (line 602), capture `runID`, `toolCallID`, sanitized `argumentsJSON` (`query_count`, `term_count`, `weights_*` numerics, `now_ms`), and `baseMetadata`.
  2. Emit `requested` immediately, then `started` immediately after (mirrors PR18 lines 74–84).
  3. Wrap the existing `try await offloadSearch { ... }` body in a measurement block; on success emit `completed` with `hit_count = results.count`, `elapsed_ms` (already computed on line 618). On catch emit `failed` with a bounded `failure_class` (e.g., `grdb_error`, `query_canceled`, `unknown`) — *not* `error.localizedDescription` (which is logged via `SearchFusionMetrics.shared.recordError(error)` but not persisted to provenance). Re-throw to preserve the throws contract.
  4. Cancellation handling: the existing `cancellation.check()` (line 603) already throws `CancellationError`; the catch arm classifies it as `failure_class = "cancelled"` and emits the cancelled terminal row before re-throwing.
- **Recorder dispatch**: `await agentProvenanceRecorder.recordToolEvent(...)` from inside the async actor method. Because `AgentToolProvenanceRecorder` is `@MainActor`, the `await` automatically hops; no manual `await MainActor.run { ... }` needed (same as PR18 ShadowSearch line 194). Persistence is fire-and-await; the call returns `Bool` for success but the AgentEvent emission is best-effort (a `false` return is logged, not propagated, mirroring PR16/PR17/PR18).
- **Tests**: extend `EpistemosTests/SearchIndexServiceFusionTests.swift` with a new suite or create `EpistemosTests/SearchIndexFusedAsyncProvenanceTests.swift` mirroring the `InstantRecallAsync*` / `ShadowSearchProvenance*` test layout. Use a real file-backed `SearchIndexService` populated via the existing Phase-5 fixture pattern, with the `EPISTEMOS_RRF_FUSION_V1` flag asserted-on for the test process. Stub the recorder via the `Persist` typealias to capture events in memory for synchronous assertions, and additionally use `EventStore.agentEvents(runID:limit:)` for the end-to-end persistence assertion.
- **Doc updates**: append PR19 status paragraph to Card 7 (between current PR18 paragraph at line 818–830 and the "naming note" at line 832–834) and tick the Card 7 closed list / `UNIFIED_SUBSTRATE_CURRENT_STATE` Bottom Line line 962.

## risks_and_p0_stop_triggers

**P0 stop triggers (must abort if any of these come up):**
1. Implementation needs to change `SearchIndexService.fusedSearchAsync(...)` throws contract (e.g., swallow GRDB errors instead of re-throwing) — that's a behavior change, not instrumentation. PR19 must preserve the rethrow.
2. Implementation needs to edit `RRFFusionQuery.swift`, `ReadableBlocksIndex.swift`, FTS5 schema, GRDB migrations, or `SearchFusionMetrics` semantics to make the recorder reachable. The recorder must be injectable via the same shape PR16/PR17/PR18 used; otherwise stop and escalate.
3. Implementation needs to edit `VaultSyncService.swift` or `QueryRuntime.swift` (the consumer call-sites) to make the recorder reachable. Instrumentation must live at the SearchIndexService boundary; consumer call-site edits are double-instrumentation and forbidden.
4. Persistence requires touching `agent_events` schema or `Epistemos/Models/AgentProvenanceEvent.swift` (new kind, new column, new field) — schema is fenced by Card 7 implementation contract (line 938–946).
5. Recorder calls measurably regress fusion search hot-path budget. Per `MASTER_RESEARCH_INDEX_2026_05_02.md` §5 + RRF design doc, the existing `OSSignposter.beginInterval("fused_search", ...)` and `SearchFusionMetrics.record(...)` are designed to be cheap; provenance must inherit that budget. Persistence is fire-and-forget bounded-JSON only; if it blocks the actor's cooperative thread or measurably slows fusion latency, stop and rework.
6. Privacy regression — any test fails the "no query text / no fused-result body / no GRDB error string / no fusion score values" invariants. Sanitized JSON only.
7. Implementation tries to project AgentEvents into OpLog / GraphEvent / Halo / Theater / ReplayBundle (Card 7 stop trigger).
8. Implementation tries to instrument the sync `fusedSearch(...)`, the legacy `search(query:limit:)`, `searchBlocks(...)`, `searchAsync(...)`, or `searchBlocksAsync(...)` paths in the same PR — out of scope for PR19. Each is a separate gate.

**P1 risks (manageable but watch):**
1. **Actor isolation friction**: `SearchIndexService` is an `actor`; `AgentToolProvenanceRecorder` is `@MainActor`. The `await recorder.recordToolEvent(...)` call automatically hops MainActor — confirmed identical to PR18 ShadowSearch shape (line 194). But the `Persist` closure is `@MainActor`, so test stubs that capture into `[AgentProvenanceEvent]` need to be MainActor-isolated. Test author must use a MainActor-bound capture box (mirror the InstantRecallAsync test fixture pattern).
2. **RRF flag-gate interaction**: `RRFFusionFlags.isEnabled` is read by consumers (`VaultSyncService.searchFullAsync` line 2326 only calls `fusedSearchAsync` when the flag is on). If the flag is OFF in the test process, the new test must explicitly set the env var or call `fusedSearchAsync` directly (bypassing the consumer wrapper). Confirm the existing Phase-5 fusion tests already do this; reuse their fixture.
3. **Run-id collision** with InstantRecall / ShadowSearch / AgentGrep / AgentQueryEngine — must namespace under `search-index-fused-async-...` so audit consumers can disambiguate. Test must prove no run-id reuse across services. (Pattern: `instant-recall-...`, `instant-recall-async-...`, `shadow-search-...`, `agent-grep-...`, `agent-query-engine-...` are already in use; pick `search-index-fused-async-...`.)
4. **Counter discipline**: per-actor monotonic `search-index-fused-async:N` counter must be reset/scoped per service instance, not per-call, to match PR16/PR17/PR18 semantics. Use a `private var fusedAsyncSearchSequence: UInt64 = 0` actor-isolated field.
5. **Cancellation paths** — `async` actor methods can be cancelled cooperatively via `cancellation.check()` (line 603). The catch arm must classify `CancellationError` (or the typed `cancellation.check()` throw) as `failure_class = "cancelled"` and emit one-and-only-one terminal row even if the awaited GRDB call resolves after cancel. Mirror PR17/PR18 exactly.
6. **GRDB error class mapping** — current code logs the full `error.localizedDescription` via `SearchFusionMetrics.recordError(error)` and re-throws. The persisted `failure_class` must be a bounded enum/string set that excludes user content and SQL fragments. Provide an explicit allowlist (e.g., `grdb_error`, `query_canceled`, `unknown`) and assert in tests. Do **not** persist `error.localizedDescription` (which can contain SQL fragments and table names that leak schema structure).

## alternate_slice (if PR19 async is blocked)

**Alternate slug: `search-index-service-fused-sync-agent-event-pr19-alt`** — `SearchIndexService.fusedSearch(query:weights:now:)` (sync, nonisolated, line 557–587) AgentEvent provenance.

Rationale for alternate ordering:
- **Same chokepoint family**, just the sync sibling. Same allowed/forbidden write sets, same privacy invariants, same lifecycle shape.
- **Trickier dispatch**: the sync nonisolated method cannot `await` a `@MainActor` recorder. The recorder call must use a `Task { @MainActor [recorder] in recorder.recordToolEvent(...) }` fire-and-forget wrapper, which is a new pattern not yet pioneered in PR14–PR18. This is why it is the alternate, not the primary.
- **Trade-off**: if PR19 async is blocked (e.g., the test author finds an actor-isolation issue specific to the async fusion path), the sync alternate is the next-cleanest path because the consumer wrapper `VaultSyncService.searchFull` (line 2305) is the most-called global-vault-search entry today (the synchronous spotlight/global search hits this path).
- **Stop triggers add one extra**: any attempt to convert the sync method to async to "fix" the dispatch problem is itself a behavior change and a P0 stop. The Task fire-and-forget pattern must be the recorder-dispatch shape; if that proves too risky to ship in one slice, escalate and pick the AgentQueryEngine `runTurn(...)` non-tool-event path or a CloudLLM follow-up path instead.

## reconciled_findings (for the Codex pipeline builder)

- **The next named open AgentEvent retrieval chokepoint is `SearchIndexService.fusedSearchAsync`** — verified by Grep across `Epistemos/Sync/**`, `Epistemos/Engine/**`, and `Epistemos/KnowledgeFusion/**`: `SearchIndexService` contains zero `AgentProvenance|saveAgentEvent` references today, while every sibling search/retrieval service (`ShadowSearchService`, `InstantRecallService`, `AgentGrepService`, `AgentQueryEngine`) does. (`MASTER_RESEARCH_INDEX_2026_05_02.md` §5 + §8.)
- **The recorder shape is solved** — `Epistemos/Engine/AgentToolProvenanceRecorder.swift:1–80` defines the canonical `@MainActor final class AgentToolProvenanceRecorder` with `recordToolEvent(...)`. PR17/PR18 use it from inside actor-isolated async methods via `await`. PR19 inherits this shape one-to-one. (`MASTER_RESEARCH_INDEX_2026_05_02.md` §2.)
- **Live consumers exist and are flag-gated** — `Epistemos/Sync/VaultSyncService.swift:2289, 2326` invokes `fusedSearchAsync` from `searchFullAsync`; `Epistemos/Engine/QueryRuntime.swift:289` invokes the sync sibling from `fullText`. Provenance emits only on the path actually exercised; flag-off doesn't pollute. (CLAUDE.md "Swift RRF Cross-Index Fusion (Phases 0-7 — 2026-04-28)".)
- **Existing instrumentation seam is in place** — `SearchIndexService.fusedSearchAsync` already wraps its body with `Sig.storage.beginInterval("fused_search", ...)` (line 597) and `SearchFusionMetrics.shared.record(...)` / `recordError(...)` (lines 619, 622). AgentEvent provenance is the third (typed, persisted, bounded) entry alongside two existing observability hooks. (`MASTER_RESEARCH_INDEX_2026_05_02.md` §8.)
- **Sync sibling deferred** — keeping PR19 to the async-only chokepoint preserves the user's "smallest safe slice" preference and avoids pioneering a new sync→@MainActor `Task { ... }` fire-and-forget recorder shape mid-rail.

## recommended_slice_shape (for the deliberation brief)

A single-PR additive instrumentation that:
1. Adds a `@MainActor`-injected `agentProvenanceRecorder` parameter to `SearchIndexService.init(...)` with a defaulted production recorder.
2. Inside `fusedSearchAsync(query:weights:now:)`, after the existing empty-terms guard, emits `requested` → `started` → `completed`/`failed` AgentEvents around the existing `dbPool.read { ... RRFFusionQuery.execute ... }` block, with run-id `search-index-fused-async-{uuid}`, per-actor sequence `search-index-fused-async:N`, actor `search-index-service`, surface `fused_search_async`, sanitized arguments JSON (`query_count`, `term_count`, fusion-weight numerics, `now_ms`), result JSON (`hit_count`, `elapsed_ms`), bounded `failure_class` on error, and a cancellation terminal row.
3. Preserves the throws contract, the existing `OSSignposter` signpost, the existing `SearchFusionMetrics` record/recordError calls, the empty-terms early return, and every other public/private method on `SearchIndexService`.
4. Ships with red→green focused Swift Testing evidence under `/tmp/epistemos-search-index-fused-async-agent-event-pr19-{red,green,build}-20260502.log` and updates Card 7 / UNIFIED_SUBSTRATE / deliberation-brief docs.

## failure_proof_guardrails (for post-merge audit)

- **grep**: `grep -nE 'search-index-fused-async-' Epistemos/Sync/SearchIndexService.swift` — must find at least one match (the run-id namespace), proving instrumentation is live.
- **grep**: `grep -c 'AgentProvenance\|saveAgentEvent' Epistemos/Sync/RRFFusionQuery.swift Epistemos/Sync/VaultSyncService.swift Epistemos/Engine/QueryRuntime.swift` — must remain `0` for all three files (proves no consumer-call-site double-instrumentation).
- **log**: `/tmp/epistemos-search-index-fused-async-agent-event-pr19-green-20260502.log` ends with `** TEST SUCCEEDED **` (modulo SwiftLint package-plugin noise, per PR15–PR18 known-good cadence).
- **test**: a focused Swift Testing case named in the new/extended suite — e.g., `SearchIndexFusedAsync provenance — completed lifecycle` — must stay green across CI.
- **invariant grep**: `grep -nE '"fused_search_async"|"search-index-fused-async:' EpistemosTests/SearchIndexFusedAsyncProvenanceTests.swift` (or sibling file) — must find at least one match per literal, proving the surface/run-id constants are asserted in tests.
- **byte-identity guard**: a test or grep that confirms `SearchIndexService.fusedSearch` (sync, line 557), `search`, `searchAsync`, `searchBlocks`, `searchBlocksAsync` bodies remain unchanged from the pre-PR19 SHA — proves PR19 stayed in-scope and PR20 (sync sibling) is a separate gate.

## usefulness
**+1.** This is the cleanest narrow next slice in the AgentEvent rail after PR18: a single Swift actor file, a single user-reachable RRF cross-index fusion chokepoint, identical pattern and deliberation template to PR16/PR17/PR18, no protected-path edits, no Rust, no manual UI testing, no broad generated bindings, no App Store/Pro tier policy. It closes a live blind spot (the canonical RRF fusion path has no provenance row today, despite being the central global-vault-search rail) before any GraphEvent live consumer or OpLog repair work demands a fresh protected-path gate, and before any broader runtime AgentEvent surface (ChatCoordinator-beyond-PR3, CloudLLM-beyond-structured, Omega-beyond-ReasoningLoop) requires bespoke chokepoint identification.

CLAUDE-RETURN: role=SIDE-FLEET | slice=next-master-plan-slice-selection | round=19 | artifact=docs/fusion/fleet/round-19-next-master-plan-slice-selection/claude-side-fleet/aggregator.md | usefulness=+1 | p0=0 | p1=0
