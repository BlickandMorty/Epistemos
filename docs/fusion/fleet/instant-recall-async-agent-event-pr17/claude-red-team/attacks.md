Now I have enough context to write the attack packet.

---
role: claude-red-team
slice: instant-recall-async-agent-event-pr17
brief: docs/fusion/deliberation/instant_recall_async_agent_event_pr17_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 9
p0_attacks: 3
p1_attacks: 4
p2_attacks: 2
p3_attacks: 0
verdict: brief-revise
usefulness: +1
usefulness_reason: Brief is directionally correct but silent on cancellation, hot-path hop-back cost, and failure-signal plumbing — needs three load-bearing additions before code.
---

## Attacks

### A1 - Cancellation produces orphan AgentEvents [P0]
**Surface:** Required implementation §3-4
**Attack:** `searchAsync` is the Contextual Shadows ambient hot path (`Epistemos/State/ContextualShadowsState.swift:164-167`). Ambient typing cancels in-flight tasks frequently — caller throws away the `Task` when the next keystroke arrives. The brief mandates `requested` + `started` BEFORE `Task.detached(...)` but only specifies `completed` / `failed` for "non-UTF8 / unexpected JSON / decode failure". A cancelled task emits neither: `requested` and `started` persist with no terminal event. Run-level dashboards show "started never finished" forever and any future ETL grouping by runID treats this as a hung tool call.
**Evidence:** `Epistemos/State/ContextualShadowsState.swift:115-167`; `InstantRecallService.swift:485-488` (detached task with no cancellation handling); brief lines 40-42 enumerate three failure classes only.
**Mitigation proposed:** Brief must mandate a fourth terminal class `failure_class = "cancelled"` emitted via `Task.isCancelled` check after `instantRecallSearch(...)` returns and before the recorder hop-back, OR specify that the detached task uses `withTaskCancellationHandler` so a cancelled run still emits `toolCallFailed` with a sanitized `cancelled` marker. Without this, every keystroke-triggered cancel leaks an unterminated run into EventStore.

### A2 - Recorder hop-back reintroduces the very @MainActor cost the async path was designed to avoid [P0]
**Surface:** Required implementation §3-4
**Attack:** `AgentToolProvenanceRecorder` is hard-`@MainActor` (`AgentToolProvenanceRecorder.swift:3`), and its `Persist` typealias is `@MainActor`. To emit `completed` / `failed` from inside the detached task per the brief, every async search must hop BACK to MainActor at least once at terminal time (and also synchronously emit two events on MainActor at start). The author's own comment at `InstantRecallService.swift:472-476` explicitly calls out that the async path exists precisely to avoid MainActor hops on the ambient hot path. PR17, as written, costs ~3 MainActor jumps per ambient query. On a 200ms typing cadence with Halo/Shadows in flight, this serializes the whole ambient pipeline behind UI rendering.
**Evidence:** `InstantRecallService.swift:466-488` (design rationale); `AgentToolProvenanceRecorder.swift:3-19` (MainActor-bound recorder + Persist).
**Mitigation proposed:** Brief must either (a) state the explicit perf trade and add a "no more than 1 hop per run" constraint by emitting all three events from a single MainActor.run continuation that observes the typed result of the detached helper, OR (b) require introducing a Sendable, lock-protected mirror sink (`OSAllocatedUnfairLock` around the persist closure) so the detached task can record without hopping. Whichever path is chosen, the brief must commit to it; right now the implementation has two valid shapes with different perf footprints and no acceptance test pinning either.

### A3 - "failure detected by the async helper" has no specified signaling channel [P0]
**Surface:** Required implementation §4 + Acceptance §3
**Attack:** Today, `runSearch(handle:query:topK:)` returns `[InstantRecallResult]` and only LOGS the three failure classes (lines 498-514). Returning `[]` is indistinguishable between "successful search, no hits" and "non_utf8_json failure". The brief instructs PR17 to emit `failed` based on the async helper's failure mode, but does not require changing the helper signature — so there is no machine-readable signal to discriminate the four states. Implementations will either (a) duplicate the JSON decoding on MainActor (defeats the off-main rationale and now decodes twice), or (b) silently downgrade every empty-result query to `failed` (poisons telemetry).
**Evidence:** `InstantRecallService.swift:492-521`; brief lines 41-44.
**Mitigation proposed:** Brief must require the helper to return a typed `Result<[InstantRecallResult], InstantRecallAsyncFailureClass>` (or equivalent enum carrying `nonUtf8Json | unexpectedJsonShape | jsonDecodeFailure | success`) so the MainActor terminal recording sees the truth. Add an acceptance criterion that each of the four failure classes has a green test — current acceptance only mandates one "valid query" failure-shape test.

### A4 - Tool-call-ID counter ownership undefined; sync/async share `searchSequence` [P1]
**Surface:** Required implementation §5
**Attack:** Brief says "distinguish async calls through `instant-recall-search-async:N` tool call ids" but doesn't say whether N is a fresh counter or the existing `searchSequence` (`InstantRecallService.swift:61, 384-387`). If shared, sync IDs become non-monotonic and existing test `searchRecordsSanitizedAgentEvents` (line 344) which asserts `instant-recall-search:1` will flake whenever an async search precedes the sync one in test order. If separate, brief must name the new field — implementers may pick `asyncSearchSequence`, `searchAsyncSequence`, or `nextAsyncToolCallID()` and post-merge greps won't catch the wrong choice.
**Evidence:** `InstantRecallService.swift:61, 384-387`; `EpistemosTests/InstantRecallTests.swift:344`.
**Mitigation proposed:** Brief must explicitly mandate a separate counter (`asyncSearchSequence: UInt64`) and a separate accessor (`nextInstantRecallAsyncToolCallID()`) and add a green test "sync and async tool-call counters advance independently" so re-orderings can't invalidate either suite.

### A5 - Forbidden-grep regex misses `path`, `snippet`, `note_id`, `noteId`, `score`, `embedding` leak classes [P1]
**Surface:** Failure-proof guardrails §67 + §69
**Attack:** The denylist is `query|text|doc|body`. ContextualShadows results carry `pageId`/`path`/`snippet` (`Epistemos/State/ContextualShadowsState.swift` calls into `instantRecall.searchAsync` and the InstantRecall results carry `text` and `score`). A future implementer who serializes `note_id`, `path`, `snippet`, or raw `score` arrays into argumentsJSON or resultJSON will pass post-merge verification because none of those tokens appears in the regex. Privacy commitment is wider than the regex enforces.
**Evidence:** Brief line 67; `InstantRecallResult` (`InstantRecallService.swift:24-30` exposes `id`, `text`, `score`); `Epistemos/State/ContextualShadowsState.swift:115-167`.
**Mitigation proposed:** Extend forbidden grep to cover `argumentsJSON.*(query|text|doc|body|note[-_ ]?id|noteId|path|snippet|embedding|score|raw)` and the same superset on `resultJSON`. Add a green test that asserts result JSON contains exactly the keys `{hit_count, document_count, elapsed_ms}` (whitelist not blacklist) so future schema growth requires explicit brief change.

### A6 - elapsed_ms semantics are ambiguous between scheduler latency and FFI work [P1]
**Surface:** Required implementation §6
**Attack:** Sync path captures `start = CFAbsoluteTimeGetCurrent()` immediately before the FFI call (line 240). For async, if `start` is captured BEFORE `Task.detached(...)`, elapsed_ms includes scheduler queue + thread hop and will inflate by 5-30ms under load — making the field useless as an FFI latency signal and falsely tripping the `>10ms` warning at line 354 for healthy queries. If captured INSIDE the detached helper, the helper must return both elapsed_ms and the result (compounding A3's signature change).
**Evidence:** `InstantRecallService.swift:240-242, 485-488`.
**Mitigation proposed:** Brief must specify "elapsed_ms measures FFI work only — captured inside the detached helper, returned alongside the result/failure-class in the typed Result" and add a green test asserting elapsed_ms < some upper bound when the FFI returns synchronously, to pin the semantic.

### A7 - Lifecycle test for "valid input that yields zero hits" missing from acceptance [P1]
**Surface:** Acceptance §49-51
**Attack:** Acceptance covers (a) successful sanitized lifecycle (b) invalid input no-emit (c) existing behavior preserved. It does NOT require a test for "valid query against empty/unmatched index → completed event with hit_count=0". This is the most common case in early ambient sessions (vault not yet hydrated; see line 482 — first searchAsync triggers hydration but returns [] before hydration drains, per the 209-225 test). Without explicit coverage, an implementer could use `results.isEmpty` to short-circuit emit `failed` without anyone noticing in green tests.
**Evidence:** Brief lines 47-52; `InstantRecallService.swift:482`; `InstantRecallTests.swift:209-225`.
**Mitigation proposed:** Add an acceptance bullet: "Green test proves a valid async search whose FFI returns a well-formed empty array `[]` emits `requested → started → completed` with `hit_count = 0` and no `failure_class` in metadata."

### A8 - Surface label has no Sovereign Gate / tier audit anchor [P2]
**Surface:** Tier §6-7 + Required implementation §5
**Attack:** Brief asserts tier=Core and aggregator marks `sovereign_gate_touchpoint: none`, but the new `surface=instant_recall_async` string becomes a substrate-spine label that downstream Halo/Theater projections may key on. Doctrine §3 (three-tier ship model) and the H6 honest-discovery note about new AgentEvent variants (`MASTER_RESEARCH_INDEX_2026_05_02.md` lines 22) caution that surface taxonomy gets reused. Adding a new surface without a row in `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` opens silent tier-leakage if a Pro-only Halo projection later filters by surface and assumes Core surfaces are ambient-safe.
**Evidence:** `MASTER_RESEARCH_INDEX_2026_05_02.md` H6 (lines 22) and §2 substrate spine (lines 47-60); brief lines 6-7, 42.
**Mitigation proposed:** Brief should add one allowed-file entry to register the new surface in `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` (under the AgentEvent surface table) so tier audits can reference an authoritative list, and add a post-merge grep `surface": "instant_recall` (without the `_async` suffix) to ensure both surfaces remain enumerated and neither was renamed silently.

### A9 - errorMessage field opens an unsanitized text channel parallel to failure_class [P2]
**Surface:** Failure-proof guardrails §67
**Attack:** `AgentToolProvenanceRecorder.recordToolEvent` accepts `errorMessage: String?` (line 38). Sync path passes the failure-class slug ("non_utf8_json", etc.) — safe. But async path's helper currently logs `error.localizedDescription` (`InstantRecallService.swift:511`) which on macOS can include offending JSON bytes from `JSONSerialization`. An implementer plumbing the failure back to MainActor may pass the localizedDescription through to `errorMessage` to "preserve diagnostic detail." Forbidden-grep at line 67 only inspects `argumentsJSON`/`resultJSON`, not `errorMessage`. Privacy regression is invisible to verification.
**Evidence:** `AgentToolProvenanceRecorder.swift:38, 70`; `InstantRecallService.swift:509-512`.
**Mitigation proposed:** Brief must explicitly state "errorMessage MUST be one of the canonical failure_class slugs and MUST NOT carry `error.localizedDescription` or any FFI-derived text" and extend the forbidden-grep to `errorMessage:.*(query|text|doc|body|path)`. Acceptance test should assert `event.tool?.errorMessage` is in the closed set `{nil, "non_utf8_json", "unexpected_json_shape", "json_decode_failure", "cancelled"}`.

## Brief verdict

The slice is correctly scoped to Core-only with no Sovereign/Pro/Research touchpoints, the file allowlist is tight, and the privacy invariants (no query/doc/body) are well-named. But three load-bearing decisions are unspecified and will block a clean PR: **(1) cancellation handling for an ambient hot path that cancels constantly**, **(2) the typed signaling channel between the detached helper and MainActor recorder**, and **(3) the explicit perf trade for re-introducing MainActor hops on a path whose comment block exists to forbid them**. Until the brief commits to a specific shape on those three (and the test acceptance grows to cover the empty-result success case + cancellation), an implementer faces multiple plausible designs with materially different correctness and perf properties — exactly the drift the deliberation step is supposed to close. Recommend revise-and-resubmit; the slice itself is sound and worth shipping once the four post-revise gaps (A1–A4) are closed.

CLAUDE-RETURN: role=RED-TEAM | slice=instant-recall-async-agent-event-pr17 | round=16 | artifact=docs/fusion/fleet/instant-recall-async-agent-event-pr17/claude-red-team/attacks.md | usefulness=+1 | p0=3 | p1=4
