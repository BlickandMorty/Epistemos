---
role: claude-red-team
slice: query-runtime-rrf-fused-fulltext-pr34
brief: docs/fusion/deliberation/query_runtime_rrf_fused_fulltext_pr34_deliberation_2026_05_03.md
date: 2026-05-03
attacks_total: 9
p0_attacks: 0
p1_attacks: 3
p2_attacks: 3
p3_attacks: 3
verdict: brief-revise
usefulness: +1
usefulness_reason: Surfaces a reactive-dependency drift, two behavioral test gaps, and a fused→note coercion that quietly drops universal-projection hits.
---

## Attacks

### A1 — Reactive `.all` query loses readable_blocks invalidation under flag-on [P1]
**Surface:** `Epistemos/Models/QueryTypes.swift:237-245` `QueryPlan.QueryStep.dependencies` for `fts5Search(.all)`; consumed by `ReactiveQuery.shouldInvalidate` after the brief's hunk lands at `Epistemos/Engine/QueryRuntime.swift:355-382`.
**Attack:** Once `RRFFusionFlags.isEnabled && scope == .all`, the fullText path reads from a third source (`readable_blocks` / `readable_blocks_fts` via `RRFFusionQuery.sql`) but `QueryStep.dependencies` for `.all` still resolves to only `[.searchPages, .searchBlocks]` — there is no `searchReadable` key in `QueryDependencyKey`. Writes that touch `readable_blocks` only (Documents, RawThoughts, Code artifacts via `EpdocDocument.searchBlocksJSONL` / `ReadableBlocksIndex.insert`) never produce `.searchPages` or `.searchBlocks` notifications, so a `ReactiveQuery` over `.fts5Search(.all)` will silently go stale until a page or block write accidentally kicks it. The slash-menu / @-mention surface that this site exists to feed is the most reactive surface in the app, and the brief deliberately bans touching `QueryTypes.swift` / `ReadableBlocksIndex` / `SearchIndexService`, so the bug ships with the recovery.
**Evidence:** `Epistemos/Models/QueryTypes.swift:237-245`; `Epistemos/Sync/SearchIndexService.swift:1608,1618,1638,1668,1678,1749,1805` (only `searchPages`/`searchBlocks` are ever published — no `searchReadable` notify exists); `Epistemos/Sync/ReadableBlocksIndex.swift:172,223` (no `notifyIndexChanged` call site at all); `docs/RRF_FUSION_DESIGN.md:281` ("snippet text propagates through `FusedResult.snippet`" — implies surface relies on fused source).
**Mitigation proposed:** Either (a) widen the brief's allowed-files set to add a `case searchReadable` to `QueryDependencyKey`, append it to `.all` dependencies, AND wire `notifyIndexChanged([.searchReadable])` into `ReadableBlocksIndex.insert/remove` — same shape as the existing page/block notify sites; or (b) explicitly carve the reactive-invalidation gap into the brief as known-deferred drift, log it in `KNOWN_ISSUES_REGISTER.md`, and add a `QueryRuntimeTests` source-guard that fails as soon as `QueryDependencyKey` gains `searchReadable` so a future close-out can't ship without flipping `.all` over too. Option (a) closes the bug; option (b) at least stops it from being silently invisible.

### A2 — "Falls through to legacy on fused-path failure" has zero behavioral coverage [P1]
**Surface:** Brief Acceptance bullet "Fused-path failures fall through to legacy dispatch"; tests at `EpistemosTests/QueryRuntimeTests.swift:906-924` ("queryRuntimeRRFFusedPathStaysFlagGatedAndFallsBack").
**Attack:** The "falls back" claim is asserted *only* by `source.contains("Falling back to legacy per-index dispatch")` — a string check on the source text, not a runtime behavior check. There is no test that injects a `SearchIndexService` whose `fusedSearch` throws (e.g., FTS5 syntax error, malformed query, missing `readable_blocks_fts` table during a partial migration) and asserts the legacy dispatch still returns the page/block hit. A future refactor that moves the `do/catch` boundary, returns `[]` from the catch, or stops calling the legacy path will pass `loadMirroredSourceTextFile` so long as the literal string survives. Source-text guards do not protect behavior; they protect comments.
**Evidence:** `EpistemosTests/QueryRuntimeTests.swift:907-913` (only string-presence asserts); brief acceptance line 41 `Fused-path failures fall through to legacy dispatch`; brief decision text line 9 "fall back to the legacy page + block searches when ... fused search throws."
**Mitigation proposed:** Add a `@Test` in `QueryRuntimeTests.swift` that:
  1. Sets `EPISTEMOS_RRF_FUSION_V1=1` (with the existing `defer { unsetenv(...) }` shape from the line-841 test);
  2. Constructs a `SearchIndexService` whose underlying file has had `readable_blocks_fts` torn down (or pass a malformed query that the fused SQL rejects but `searchAsync(query:limit:)` accepts);
  3. Seeds a normal page hit;
  4. Asserts `runtime.fullText(query: ..., scope: .all)` still returns the page hit (proving fall-through). The brief's allowed-files set already covers `QueryRuntimeTests.swift`, so this can land in the same PR.

### A3 — `.pages` / `.blocks` "do not use fusedSearch" is also source-text-only [P1]
**Surface:** Brief Acceptance bullet "`.pages` and `.blocks` do not use `fusedSearch`."; QueryRuntime guard at `Epistemos/Engine/QueryRuntime.swift:355` (`scope == .all`).
**Attack:** No test exercises `runtime.fullText(query:..., scope: .pages)` or `.blocks` *with the flag on* and asserts the fused path was not entered. The line-841 test only checks that `.pages` returns empty when a `readable_blocks`-only doc is seeded — that is consistent with both the correct guard `scope == .all` AND a buggy guard `scope == .all || scope == .pages` that fused-search-then-filter. If a future refactor flips the guard to `scope != .blocks` (mirroring the legacy `.pages || .all` shape on line 384) the test still passes because the readable-block content lives in a doc kind that maps to `.note` in the GraphStore. A behavioral spy is needed.
**Evidence:** `EpistemosTests/QueryRuntimeTests.swift:885` (the `.pages` arm asserts emptiness, not call-graph isolation); `Epistemos/Engine/QueryRuntime.swift:355` (single-line guard with no telemetry hook).
**Mitigation proposed:** Add a `SearchIndexService` test double (e.g., a subclass overriding `fusedSearch` to throw `XCTFail`-style sentinel error) and assert that flag-on `.pages` and `.blocks` calls succeed without entering the fused path. Alternatively, increment a `@TestOnly` counter on `SearchFusionMetrics.shared` per-call and assert it stays at 0 for non-`.all` scopes. Either approach lives entirely in `QueryRuntimeTests.swift` per the brief's allowed-files set.

### A4 — Universal-projection hits whose parent is not a `.note` are silently dropped [P2]
**Surface:** `Epistemos/Engine/QueryRuntime.swift:362-372` (fused loop) → `appendNoteResult(...)` → line 447 `graphStore.node(bySourceId: pageId, type: .note)`.
**Attack:** The fused query returns `entityKind ∈ { 'page', 'block', <ArtifactKind snake_case> }` (RRFFusionQuery.swift:295, 309, 326). For Documents / RawThoughts / Code artifacts in `readable_blocks`, `parentDocID == artifact_id` and the matching graph node is registered as `.document`, `.rawThought`, or `.code` — *not* `.note`. `appendNoteResult` requires `type: .note` and silently returns nothing for the others. The fused promise (per `RRF_FUSION_PROMPT.md:10` "across `page_search`, `block_search`, AND the new `readable_blocks` table") becomes a half-promise: the universal projection's *non-note* surface is invisible to this consumer. The single line-841 test masks the bug by seeding the readable_block under a `.note` graph node (`makeNoteNode(id: "note-readable", sourceId: "doc-readable", ...)`), so the test is green even though Document/RawThought autocomplete can never light up.
**Evidence:** `Epistemos/Engine/QueryRuntime.swift:447`; `EpistemosTests/QueryRuntimeTests.swift:866` (test seeds `.note` node for a `kind: .document` block — masks the gap); `Epistemos/Sync/RRFFusionQuery.swift:295,309,326` (entity_kind enumeration).
**Mitigation proposed:** Either (1) accept this is by-design for "Epdoc Slash menu / @-mention block-link autocomplete" (which is note-link-only) and add an explicit comment + test that asserts non-`.note` results are dropped — making the contract honest; or (2) generalize `appendNoteResult` to look up by `entityKind` → `GraphNodeType` and accept Document / RawThought / Code so the universal projection actually surfaces. Option (1) keeps brief scope; option (2) honors the canon's "wire it into every site where unified search is currently fragmented."

### A5 — AgentEvent emission on every interactive slash-menu keystroke [P2]
**Surface:** `Epistemos/Engine/QueryRuntime.swift:357-359` calls `searchIndex.fusedSearch(...)` which at `Epistemos/Sync/SearchIndexService.swift:917-986` emits 3 AgentEvents per call (`toolCallRequested`, `toolCallStarted`, `toolCallCompleted` or `toolCallFailed`).
**Attack:** Slash-menu / @-mention autocomplete fires per keystroke. Pre-PR the legacy path called `searchIndex.search` + `searchIndex.searchBlocks` which (verify against current implementation) do not generate AgentEvent storms on the search hot path. Post-PR every keystroke under flag-on writes 3 AgentEvent rows to the durable AgentEvent store via `agentProvenanceSyncRecorder` — a hot-path side-effect that wasn't present in HEAD and that the brief's "Source guards keep the slice out of ... GraphEvent writes, MutationEnvelope writes" list never explicitly covered for AgentEvent. This is a doctrine §1 invariant-3 concern (Markov blanket: side-effects on hot path) more than a correctness bug, but it raises retrieval cost on the most user-facing surface in the app.
**Evidence:** `Epistemos/Sync/SearchIndexService.swift:917-986` (AgentEvent ceremony around the fused-sync path); brief acceptance bullet line 44 lists GraphEvent + MutationEnvelope but is silent on AgentEvent.
**Mitigation proposed:** Verify whether `agentProvenanceSyncRecorder`'s default is no-op for the QueryRuntime call site (it likely is, since `searchIndex` was constructed without an explicit recorder injection in the line-148 test — confirm before merge). If non-trivial in production, gate AgentEvent emission inside `fusedSearch` behind a `signal_kind: .interactive` parameter that QueryRuntime passes (and HomeView landing search omits). Add an explicit brief acceptance line clarifying AgentEvent emission policy.

### A6 — Top-K prepared-index re-ranker can shuffle a fused result by an unrelated similarity score [P2]
**Surface:** `Epistemos/Engine/QueryRuntime.swift:373-374` `graphEventHintedCandidates(scoredCandidates(query: query, candidates: candidates))` for the fused branch.
**Attack:** The fused branch flows the RRF-ordered candidates through the same `scoredCandidates` (top-K=12 reranker) and `graphEventHintedCandidates` pipelines as the legacy branch. `PreparedIndexSimilarityScorer` re-ranks the top-12 candidates using ANN cosine against a Rust-built embedding index — but the fused candidates already carry RRF + recency rankings tuned by `RRFFusionQuery.sql:391` (`ORDER BY fused_score DESC, updated_at_unix DESC, entity_id ASC`). Stacking ANN re-ranking on top of RRF can re-introduce calibration mismatches (the very problem RRF was chosen to avoid per `RRF_FUSION_PROMPT.md:132` "RRF discards raw scores entirely"). No test in `QueryRuntimeTests.swift` exercises the fused-path × scorer interaction.
**Evidence:** `Epistemos/Engine/QueryRuntime.swift:373-374`; `Epistemos/Engine/QueryRuntime.swift:254-310` `PreparedIndexSimilarityScorer.score`; `RRF_FUSION_PROMPT.md:132`.
**Mitigation proposed:** Add a `@Test` (allowed in QueryRuntimeTests) that constructs a `PreparedIndexSimilarityScorer`-equipped runtime, seeds a fixture where RRF and ANN disagree on top-2 ordering, runs flag-on `.all`, and asserts whichever ordering is intended. Document the layering decision in `RRF_FUSION_DESIGN.md` §14. If RRF should be authoritative, short-circuit the prepared-index scorer when `RRFFusionFlags.isEnabled && scope == .all`. Either choice is fine; silence is not.

### A7 — `query` text logged at `.public` privacy on every fused failure [P3]
**Surface:** `Epistemos/Engine/QueryRuntime.swift:378` `Log.ffiBoundary.error("QueryRuntime: fusedSearch failed for '\(query, privacy: .public)': ...")`.
**Attack:** When fusedSearch throws (FTS5 syntax error, sandbox transient, etc.), the user's literal slash-menu / @-mention query text is written into the system log at `.public` privacy. Slash-menu queries can contain personal names, project codenames, or other PII. The legacy branch does the same (lines 399, 419), so this is not a regression — but the brief is the moment to flag it because the fused branch is on the path to default-on. Tier matrix puts Core (App Store) on this path.
**Evidence:** `Epistemos/Engine/QueryRuntime.swift:378,399,419`.
**Mitigation proposed:** Out of scope for this slice but should be filed against the wider RRF Phase 4 hardening — switch to `.private` privacy for the user-supplied portion of the query, leaving error-class context as `.public`. Explicitly note in this brief that the query-text-leak parity is acknowledged and tracked.

### A8 — `RRFFusionFlags.isEnabled` reads `ProcessInfo.environment` on every keystroke [P3]
**Surface:** `Epistemos/Sync/RRFFusionQuery.swift:147-149` (computed property); called from `Epistemos/Engine/QueryRuntime.swift:355` per call.
**Attack:** `ProcessInfo.processInfo.environment` is a non-cached dictionary materialized on each access. Slash-menu autocomplete fires per keystroke, so the env-var lookup runs N times per typing burst. Cost is small (μs) but it is hot-path overhead added by this slice. A future tightening of the flag (e.g., to a Settings toggle) will need to revisit this.
**Evidence:** `Epistemos/Sync/RRFFusionQuery.swift:147-149`.
**Mitigation proposed:** Snapshot the flag once into a `let isEnabled = RRFFusionFlags.isEnabled` at the top of `fullText` so the `&& scope == .all` short-circuit doesn't re-read env on every call. Trivial single-line change inside the allowed-files boundary.

### A9 — Verification gate runs only `QueryRuntimeTests`, not the broader regression suite [P3]
**Surface:** Brief verification block lines 47-50.
**Attack:** The verification command is `-only-testing:EpistemosTests/QueryRuntimeTests`. Real regressions in this slice can land in `SearchIndexServiceFusionTests`, `RRFFusionQueryTests`, `ReadableBlocksIndexTests`, `ReactiveQuery*Tests`, or any FTS5-touching test that depends on this code path. Per CLAUDE.md non-negotiable "Zero test regressions against the 2,679-test suite," limiting verification to one suite is below the floor.
**Evidence:** Brief lines 47-50; CLAUDE.md "Zero test regressions against the 2,679-test suite."
**Mitigation proposed:** Either widen the verification command to the full `EpistemosTests` target (no `-only-testing`), or add a separate verification line that runs the search-index suites in particular: `-only-testing:EpistemosTests/QueryRuntimeTests -only-testing:EpistemosTests/RRFFusionQueryTests -only-testing:EpistemosTests/SearchIndexServiceFusionTests -only-testing:EpistemosTests/ReadableBlocksIndexTests`. The first option matches the canon non-negotiable; the second is a faster bridge.

## Brief verdict

**brief-revise.** The recovery itself is correct, narrow, and additive — the candidate hunk at `QueryRuntime.swift:349-382` is a clean Phase-4 site-3 wiring with the right guard (`RRFFusionFlags.isEnabled && scope == .all`), the right argument (`FusionWeights(maxResults: limit)`), and a real catch + fall-through. The brief is, however, asking the merge to ship two acceptance bullets ("falls through to legacy" and "`.pages`/`.blocks` do not use fusedSearch") that have *no behavioral coverage* — only source-text greps (A2, A3, both P1). And it ships an unflagged reactive-dependency drift on the most reactive surface in the app (A1, P1) by deliberately keeping `QueryTypes.swift` out of allowed files.

The smallest revision that closes the P0/P1 surface:

1. **A1**: Either add `Epistemos/Models/QueryTypes.swift` + `Epistemos/Sync/ReadableBlocksIndex.swift` to allowed files and wire a `searchReadable` dependency key end-to-end, or explicitly carve the gap into the brief as a known-deferred follow-up with a fail-on-regress `QueryRuntimeTests` source guard. Picking option (b) is fine for a recovery slice; silently shipping it is not.
2. **A2 + A3**: Add two real `@Test` cases in `QueryRuntimeTests.swift` (already in allowed files): one with a stub/throwing `SearchIndexService.fusedSearch` proving fall-through, and one asserting flag-on `.pages` / `.blocks` never enter the fused path.

P2/P3 items can land as follow-up tickets (`AgentEvent` chattiness in A5, prepared-scorer × RRF layering in A6, log privacy in A7, env-var hot-read in A8, verification widening in A9). Once the three P1s are addressed, this slice is mergeable and cleanly closes the canon/code drift the detective + aggregator identified.

## Codex disposition after revision

- **A1 closed in this slice.** `QueryDependencyKey.searchReadable` was added, `.fts5Search(.all)` now depends on it, and `ReadableBlocksIndex` posts `.searchReadable` invalidation for insert, replace, and delete mutations.
- **A2 closed in this slice.** `retrievalRuntimePreservesLegacyResultsWhenRRFFusedPathFallsBack` now drops `readable_blocks_fts` to force fused search failure and asserts the legacy page hit still returns.
- **A3 closed in this slice.** `retrievalRuntimeKeepsNonAllScopesOffRRFFusedPath` runs flag-on `.pages` and `.blocks` searches and asserts `SearchFusionMetrics` records no fused query or fused error.
- **A4-A9 accepted as P2/P3 follow-up surface.** They do not block this recovery commit because the flag remains opt-in, the default Core path is unchanged, and the post-merge guard list records the known RRF hardening edges.
