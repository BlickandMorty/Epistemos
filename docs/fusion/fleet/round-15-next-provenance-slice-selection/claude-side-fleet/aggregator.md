# round-15-next-provenance-slice-selection

## recommended_slice
**Broader AgentEvent runtime coverage — pick the next named chokepoint after Card 7 PR16.** Concretely: `InstantRecallService.searchAsync(query:topK:)` provenance (call it PR17), since `searchAsync` is the only InstantRecall path explicitly named open in Card 7's allowed-write-set (line 889) and is the natural mirror to PR16's just-closed sync path.

## why_now
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` lines 670–673 list "AgentEvent emission beyond …" as a still-open gate, with InstantRecall `searchAsync(query:topK:)` explicitly *not* yet covered.
- Card 7 has a 16-PR cadence of identical shape (additive, sanitized, surface-scoped). The pattern, tests, deliberation template (`instant_recall_agent_event_pr16_deliberation_2026_05_02.md`), and red/green log naming are all already proven.
- The other two candidates need a *new* deliberation gate that touches Card 8's forbidden write set (`Epistemos/Graph/**`, `Epistemos/Views/Graph/**`, renderer) or Card 6's stop-trigger boundary (mutating repair beyond read-only). That's a higher-risk slice than the next PR in an active cadence.
- Substrate spine doctrine (`MASTER_RESEARCH_INDEX_2026_05_02.md` §2) treats AgentEvent and GraphEvent as parallel projection rails; closing AgentEvent breadth first keeps the rail symmetric before live consumers light up.

## files_to_read
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` (lines 663–694, "Still open" + safe build order §3)
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 (especially lines 884–893 future allowed and lines 1132–1141 stop triggers)
- `docs/fusion/deliberation/instant_recall_agent_event_pr16_deliberation_2026_05_02.md` (template to mirror)
- `Epistemos/KnowledgeFusion/InstantRecallService.swift` (target chokepoint — `searchAsync(query:topK:)`)
- `Epistemos/Models/AgentProvenanceEvent.swift` (typed payload contract)
- `Epistemos/State/EventStore.swift` (`saveAgentEvent`/`loadAgentEvent`/`agentEvents` API surface)
- `EpistemosTests/InstantRecall*Tests.swift` and `EpistemosTests/CognitiveSubstrateTests.swift` (extend, do not fork)
- `/tmp/epistemos-instant-recall-agent-event-pr16-green-20260502.log` (acceptance-evidence template)

## likely_write_set
- `Epistemos/KnowledgeFusion/InstantRecallService.swift` — additive instrumentation around the async-path entry/exit/cancellation, mirroring PR16 sync emission with `instant-recall-async-…` run ids and `instant-recall-search-async:N` tool ids.
- New focused Swift Testing file (e.g., `EpistemosTests/InstantRecallAsyncProvenanceTests.swift`) or extension of the existing PR16 suite.
- New deliberation gate under `docs/fusion/deliberation/instant_recall_async_agent_event_pr17_deliberation_2026_05_02.md`.
- Status update lines in `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` and Card 7 status block.

## forbidden_set
- `agent_core/**` (Card 7 forbidden)
- `Epistemos/Views/Notes/ProseEditor*.swift`, `Epistemos/Views/Graph/MetalGraphView.swift`, `Epistemos/Views/Graph/HologramController.swift`, `Epistemos/Graph/**`, `graph-engine/**`, `epistemos-shadow/**`
- generated UniFFI Swift/header bindings, generated libraries, Xcode project files, entitlements, DerivedData, `.xcresult`
- Approval/routing/UI/streaming control-flow changes (Card 7 implementation contract)
- Persisting query text, note ids, note bodies, snippets, vault paths, source text, async-result text, ShadowSearch internals (PR16 privacy invariants)
- Branch operations / commits / stashes
- Any AgentEvent → OpLog/GraphEvent/Halo/Theater/ReplayBundle projection (separate gate required per Card 7 line 914–915)

## tests
- **Red**: focused test that calls `searchAsync` and asserts the existing AgentEvent table contains no `instant-recall-async-…` rows (proves missing instrumentation).
- **Green**: focused Swift Testing suite that proves
  - requested → started → completed/failed lifecycle rows with non-empty run id, tool call id, actor `instant-recall-service`, surface=`async`
  - sanitized argument/result JSON: only topK, query-count, hit count, document count, elapsed ms, failure class — no query text, body, snippet, vault path, async event text, Halo/ShadowSearch state
  - cancellation path emits `failed` with bounded reason (`cancelled`)
  - empty/invalid-input early returns do not record bogus rows (mirrors PR16 invariant)
- **Source guards**: grep that no new `LocalAuthentication`, OpLog, GraphEvent, Halo, Theater, agent_core, generated-binding, editor-protected, or graph-protected symbols appear in the diff.
- **Build**: `xcodebuild -scheme Epistemos -destination 'platform=macOS' build-for-testing` and the focused test target, logging to `/tmp/epistemos-instant-recall-async-agent-event-pr17-{red,green}-20260502.log` per Card 7 naming.
- `git diff --check` + protected-path name-only diff scan.

## red_team_risks
1. **Cancellation/early-return paths** — async tasks have multiple exit points (cooperative cancel, throw, completed-with-empty); each must emit exactly one terminal event or the row count drifts.
2. **Run-id collision** with PR16 sync surface — namespace under `instant-recall-async-…` (or surface=`async`) so audit consumers can disambiguate.
3. **Privacy regression** — async result hydration may carry result text or note bodies in scope; must clamp to counts only, exactly as PR16 does. Re-use PR16's sanitization helpers, do not invent new ones.
4. **Double-counting** if `searchAsync` internally awaits the sync path (or vice versa) — must instrument *only* the public chokepoint and assert via test that one user call yields exactly one provenance run.
5. **Existing async metrics surface** (Halo / ambient-recall counters) must remain untouched; instrumentation is additive only and cannot move bookkeeping.
6. **Stop-trigger drift** — if instrumentation requires a new public method on `InstantRecallService` or an injection surface, that's a stop trigger ("approval/routing/tool execution semantics changes"). Inject the recorder via the same shape PR16 used.

## usefulness
+1 — closes a named open item with the lowest-risk, highest-pattern-reuse PR available; preserves the symmetric AgentEvent rail before any live GraphEvent consumer or OpLog repair work needs a new gate. Comparison verdicts:

| Slice | Verdict |
|---|---|
| Live GraphEvent consumer beyond Halo ribbon | **0** — first non-Halo live consumer crosses Card 8's forbidden write set (`Epistemos/Views/Graph/**` / `Epistemos/Graph/**`) and trips Card 8's stop trigger; needs a fresh protected-path gate naming exact files. Useful eventually, not the safest next slice. |
| Broader AgentEvent runtime coverage | **+1** — Card 7's PR-by-PR cadence is open, additive, well-templated; `searchAsync` (and similarly any future ChatCoordinator path beyond PR3 or CloudLLM path beyond generate/stream/structured) needs only a small new gate, no protected-path edits. |
| OpLog production visibility / audit / repair-next | **0** — read-only ReplayBundle visibility surface could be a +1 sub-slice, but the broader "repair-next" framing crosses Card 6's stop trigger ("starts adding UI/AgentEvent/GraphEvent features instead of closing the projection contract") and would need to engage doctrine §0 H8's open WAL/`prev_hash`/`F_FULLFSYNC` gaps. Not safest next. |

CLAUDE-RETURN: role=SIDE-FLEET | slice=round-15-next-provenance-slice-selection | round=15 | artifact=stdout | usefulness=+1 | p0=0 | p1=6
