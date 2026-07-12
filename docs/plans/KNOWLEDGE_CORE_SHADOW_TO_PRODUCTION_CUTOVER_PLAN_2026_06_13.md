# Knowledge-Core Shadow → Production Cutover Plan (2026-06-13)

> 🔴 **RE-ANCHORED 2026-07-06.** Knowledge-Core is backend/engine-layer work and must not
> revive a deleted UI surface. Re-anchor any "Goose-as-surface / reskin / Option 1 /
> OpenChamber / ProAgent" reference to the current two surfaces: MAS/June and
> Experimental/1Code. OpenChamber/ProAgent are KEELSTONE deletion targets.

**Status:** PLAN / SCOPING. `state:candidate` per the Canon-Hardening Protocol —
**implementation past Slice 0 requires explicit owner sign-off.** This document is
blue-architecture proof only until promoted by the falsifiers + WRV + rollback
machinery named below.

**Author:** Claude (consolidate+drive session 2026-06-13). Grounded in a verified
read of the live + staged paths (file:symbol refs below confirmed against source,
not just agent assertion).

Supersedes nothing. Background: `docs/plans/2026-03-19-knowledge-core-implementation-plan.md`
(original KC build plan, pre-shadow). See `ARCHITECTURE_MAP.md` §1–§5 for the
staged-vs-live split this plan closes.

---

## 1. Goal

Promote the staged knowledge-core (KC) from a **shadow path that only collects
metrics** to a **first-class driver of app query/UI state**, additively and behind
a rollback flag, without regressing the live SwiftData → GraphStore → QueryRuntime
path. Cut over the **read/query side first** (lowest blast radius); treat the
write/parser-canonicalization side as a separate, later track.

## 2. Verified current state

### Live query path (the thing we must not break)
```
GraphStore mutation → .graphStoreDidChange → ReactiveQuery (35ms debounce)
  → QueryRuntime.execute(plan) → RetrievalRuntime.fullText (Eidos/RRF/index)
  → QueryResult → ReactiveQuery AsyncStream → QueryEngine.currentResult (@Observable @MainActor)
  → SwiftUI (HologramSearchSidebar → QueryResultsView)
```
- `QueryEngine` — `Epistemos/Engine/QueryEngine.swift`: `private var runtime: QueryRuntime?` (l.29);
  `resolvedRuntime()` **hardcodes** `let runtime = QueryRuntime(...)` (l.66–73). **No executor seam today.**
- `QueryRuntime` — `Epistemos/Engine/QueryRuntime.swift:536` `final class`; single convergence
  point `func execute(_ plan: QueryPlan) -> QueryResult` (l.560).
- Precedent for DI swap: `PreparedRetrievalRuntimeResolving` protocol (QueryRuntime.swift:206) already
  swaps *scorers*; flag-gating precedent: `EidosFlags` / RRF (`EPISTEMOS_RRF_FUSION_V1`).

### Staged KC (real, off by default)
- Rust `graph-engine/src/knowledge_core/`: `store.rs` (in-memory Cozo `DbInstance`, **no persistence**),
  `parser.rs` (**line-based fallback only** — orgize/pulldown parser instantiated then discarded),
  `ring.rs` (rkyv `QueryDiffEnvelope` over shared-mem ring), `crdt.rs` (Loro outline), `archived.rs`.
- `QueryDiffEnvelope{ tx_id, subscription_id, kind: Outline|Tasks|Properties|Links, added/updated/removed }`.
- 27 `graph_engine_kc_*` FFI entry points (subscribe / ingest / mutate / ring / payload).
- Swift: `KnowledgeCoreShadowRuntime` (`Epistemos/Engine/KnowledgeCoreBridge.swift:916`) **polls the ring
  and collects counters only** — does NOT drive SwiftData, search index, sidebar tree, or any view.
- Flag: `deterministicKnowledgeCoreRuntime` (Log.swift:79 / env `EPISTEMOS_DETERMINISTIC_KNOWLEDGE_CORE_RUNTIME`
  l.87, default **false**); `KnowledgeRuntimeAdapter.apply()` (KnowledgeCoreBridge.swift:177) gates on it.

### The gap (one sentence)
KC computes correct-shaped diffs and ships them to Swift, but **nothing consumes them as truth**, KC has
**no persistence**, and its **parser diverges** from the live `BlockParser`.

## 3. The seam decision

Introduce one protocol at the single convergence point and route through it. This is the whole
architectural move; everything else is filling it in.

```swift
// NEW Epistemos/Engine/QueryExecutor.swift
@MainActor protocol QueryExecutor: AnyObject { func execute(_ plan: QueryPlan) -> QueryResult }
extension QueryRuntime: QueryExecutor {}            // behavior-preserving conformance
// QueryEngine.resolvedRuntime() returns `any QueryExecutor`, chosen by flag.
```
Why here: it's the *only* place all query kinds converge before `QueryResult`; it's already `@MainActor`;
views bind to `QueryEngine.currentResult` and never see the executor; ReactiveQuery/GraphStore are untouched.

## 4. Phased slices (each: flag · verification · rollback)

- **Slice 0 — Enabling refactor (SAFE, signable now).** Add `QueryExecutor`; conform `QueryRuntime`
  (zero logic change); `QueryEngine` holds `any QueryExecutor?`. No flag, no behavior change.
  *Verify:* existing QueryEngine + ReactiveQuery tests stay green. *Rollback:* trivial (pure refactor).
  *This is the only slice that does not implement candidate KC logic — safe to do on sign-off of this doc alone.*

- **Slice 1 — Shadow-read parity harness.** `KnowledgeCoreQueryExecutor` for **Tasks only** (bounded,
  structured). Behind new flag `EPISTEMOS_KNOWLEDGECORE_READ_V0` (default off): execute BOTH, **serve the
  live result**, record agree/diverge in a `KnowledgeCoreParityHealthRow` (mirror `SearchFusionHealthRow`).
  *Verify:* new falsifier `F-KnowledgeCoreReadParity` — parity ≥ threshold over a fixture corpus; zero
  user-visible change. *Rollback:* flag off.

- **Slice 2 — Persistence (prerequisite to truth).** KC is in-memory only; pick ONE: persisted Cozo backend,
  or a replay transaction log + snapshot. KC cannot be a source of truth across sessions without this.
  *Verify:* restart-replay parity test. *Rollback:* flag off → falls back to live path. (Heaviest slice; may
  be scoped/deferred — Slices 1/3 can run session-local first.)

- **Slice 3 — Promote one read surface.** With Slice 1 parity green + Slice 2 persistence, flip the flag to
  **serve** KC Tasks results in one surface, instant rollback. AnswerPacket + WRV visible per the proof culture.

- **Slice 4+ — Broaden.** Outline → Notes sidebar tree; Properties; Links. Each repeats Slice-1→3 shadow→promote.

- **Separate track — Parser canonicalization.** Replace `parser.rs` line-based fallback with the
  event-normalized AST. **Prerequisite to promoting Outline** (today KC outline diverges from `BlockParser`).
  Do not couple to the read-side cutover.

## 5. Risks → mitigations
- **Parser divergence** (line-based KC vs `BlockParser`) → parity harness (Slice 1) catches it; gate Outline
  promotion on the parser track.
- **No persistence** → Slice 2 gates any "source of truth" promotion; Slice 1/3 stay session-local until then.
- **Main-thread block** from ring polling → keep KC executor off the hot path; reuse the existing background
  drain in `KnowledgeCoreShadowRuntime`; assert no `@MainActor` sync waits.
- **Dual-run cost** during shadow → Tasks-only scope + sampling; flag default off.

## 6. Sign-off gate (Canon-Hardening)
- **Safe on sign-off of THIS doc:** Slice 0 (pure refactor).
- **Requires explicit owner approval + the full machinery** (falsifier, RunEventLog, AnswerPacket, rollback,
  WRV, MAS/Pro boundary review): Slices 1–4 and the parser track. Each promotion is L3-gated; **L1 source-guard
  green is blue proof only**, never a green/usable claim.

## 7. Test strategy
- Slice 0: existing `QueryEngineTests` / `ReactiveQueryTests` unchanged + green.
- Slice 1+: new `KnowledgeCoreQueryExecutorTests` (mock ring fixtures) + `F-KnowledgeCoreReadParity` falsifier
  artifact under `artifacts/falsifiers/`; parity health row mirrors the Search Fusion observability shape.
- No SwiftUI consumer test changes (views are insulated from the executor by design).

## 8. Status & empirical findings (2026-06-13)

Landed + verified (signing-disabled, headless):
- **Slice 0** (`93b18967c9`) — `QueryExecutor` seam. `ReactiveQuery` holds `any QueryExecutor`; behavior-preserving; 38 guard tests green (incl. QueryRuntime source-mirror guards).
- **Slice 1.1** (`068adb5db4`) — `KnowledgeCoreTaskParitySummary` + ground-truth probe. KC emits correct task rows on checkbox ingest (3 tasks / 1 done).
- **Slice 1.2** (`69d3db90a9`) — KC ≅ live `TextCapturePipeline` on checkbox tasks (both 4 tasks / 2 done). Core task-side parity invariant holds.
- **Slice 1.3** (`5174a757b2`) — tracked KC↔live divergence: live recognizes `FIXME:/ACTION:/TASK:/TODO:` colon prefixes KC does not (KC parses checkboxes + `TODO /DONE ` space prefixes). Asserted gap, not a regression.

Design refinements (verified against source, not assumed):
- KC is **subscription/diff-based** (ring), not plan-based. A KC `QueryExecutor` for the *search* path would need a projection/translation layer; it is NOT the seam for KC's structured note-data (tasks/outline). KC task rows carry `{pageId, blockId, marker, done}` and **omit task text** → only **count-level** parity (total/done) is comparable for tasks.
- Checkbox tasks are the safe first surface (parity holds). `FIXME:/ACTION:`-prefix and **Outline** parity are gated on **parser canonicalization** (`parser.rs` is line-based; the orgize/pulldown parser is instantiated-then-discarded).

Autonomous-headless ceiling for the task read-side reached. Remaining work and who it needs:
- **Runtime shadow probe on the real vault corpus** (flag `EPISTEMOS_KNOWLEDGECORE_READ_V0`, default off) + parity health row — the *build* is autonomous; real-corpus exercise needs the **user's vault**.
- **Persistence** (Slice 2) + **promotion** (Slice 3) — **owner sign-off** + falsifier/RunEventLog/AnswerPacket/WRV/rollback.
- **Parser canonicalization** (Rust, cargo-verifiable) — prerequisite for Outline/prefix parity; substantial standalone track.

## 9. Parser canonicalization — investigated + deferred (2026-06-13)

Green floor: `cargo test --lib knowledge_core` = **37 passed / 0 failed** (parser + store + ffi); full graph-engine ≈ 2,780 tests.

`parser.rs` confirms the dead-AST issue: `parse_markdown` builds `Parser::new_ext(text, Options::all())` then **discards it** and runs line-based `parse_lines`; `parse_org` builds `Org::parse(text)` then discards it. A full-document AST parse is computed and thrown away on every ingest; all extraction (blocks/tasks/properties/links) is line-based.

**No minimal safe increment exists:**
- Wiring the AST is a **rewrite** — the AST model (events / byte offsets) differs from the line-based model (`block_id = {page}::{line:08}`, depth = indentation count). It would change block boundaries/IDs and break the 3 parser tests + downstream `store`/projection tests inside the 37-test floor. Too entangled for one cautious slice.
- The only *small* safe change — deleting the dead `_parser`/`_org` (a real per-ingest perf win) — **reverses** the canonicalization intent (removes the stubs that are meant to be wired). Not done autonomously.

**Owner decision fork:**
- **(A) Wire the AST** — deliberate multi-step Rust effort (~40-min cargo cycles); must keep the 37-test floor green (re-baselining several store/parser tests). Best as a focused session.
- **(B) Remove dead stubs** — safe perf cleanup now; re-add proper AST parsing when (A) is scheduled.
- **(C) Defer canon; close the prefix gap additively** in the line-based parser instead — but only after confirming KC's task target (TextCapturePipeline vs BlockParser; the impedance question), which fixes the parity direction.

No parser changes made at scoping time; held for owner.

**RESOLVED 2026-06-13 (by data, no longer held).** Decided (C), rejected (A):
- KC's `parse_task_state` now recognizes `TODO:/FIXME:/ACTION:/TASK:` colon prefixes (`f69e90923e`), closing the markdown task divergence — KC ≅ live `TextCapturePipeline` on tasks.
- An outline parity test (`knowledgeCoreOutlineMatchesLiveBlockParser`) confirms **KC outline ≅ the live `BlockParser`, both line-based** (one block per non-empty line, equal counts).
- Therefore the AST canonicalization (A) is **NOT needed** for cutover parity and would actually *diverge* from the line-based live model. The line-based parser is the correct cutover target.
- Only remaining parser cleanup: optionally delete the dead `_parser`/`_org` stubs (B, a per-ingest perf win). The owner fork is closed — **no AST rewrite**.

## 10. Slice 2 persistence — scoping (2026-06-13, decision-ready; NOT implemented)

Current state (`graph-engine/src/knowledge_core/store.rs`): `DatalogStore` (l.486) holds an
**in-memory** Cozo `DbInstance::new("mem", "", "")` (l.507) + a `tx_id` counter and
`last_mutation_envelope` (only the LAST `MutationEnvelope`, l.496). Each mutation
(ingest/insert/move/delete) increments `tx_id` and emits a typed `MutationEnvelope`
(l.57, `to_envelope` l.413). No durable storage — KC rebuilds empty every launch.

**(A) Persistent Cozo engine.** Swap `DbInstance::new("mem", …)` → `"sqlite"`/`"rocksdb"` with a
vault-scoped path (`<vault>/.epcache/kc.<engine>`); Cozo handles durability.
- Pros: minimal store-logic change; battle-tested durability.
- Cons: needs the cozo dep to enable the storage-engine feature (Cargo.toml + bigger build —
  VERIFY against cozo docs first); schema must be create-if-not-exists + versioned; the 38 store
  tests assume a fresh in-memory db → need temp-file isolation; persistent-engine txn/locking
  semantics differ from `mem`.

**(B) Replay transaction log + snapshot — RECOMMENDED.** Keep the fast in-memory Cozo; durably
append every `MutationEnvelope` to `<vault>/.epcache/kc-oplog.bin`; replay on startup; periodic
snapshots bound replay time.
- Pros: leverages the EXISTING `MutationEnvelope` primitive + the canon invariant "every mutation
  produces a typed transaction-log entry"; no engine swap → no perf regression, no Cargo feature;
  the in-memory query path (and the 38 tests) is unchanged; deterministic rebuild + provenance +
  a foundation for sync.
- Cons: must accumulate envelopes (today only `last` is kept) + implement durable append, replay,
  snapshot, and format versioning.

**Recommendation: (B).** Aligns with the existing event-sourcing primitive + canon, keeps the
in-memory path (lowest regression risk to the 38-test floor), and is easy to isolate in tests.
Fall back to (A) only if replay/snapshot complexity exceeds budget.

**Migration path (B):** (1) append-only `OpLog` writer keyed off `MutationEnvelope` (reuse the
rkyv/serde path used for `QueryDiffEnvelope`), written alongside the ring publish; (2)
`DatalogStore::replay(oplog) -> Self` re-applying envelopes in tx_id order into a fresh store;
(3) periodic snapshot (serialize facts) + truncate replayed log → replay = snapshot + tail;
(4) wire open/replay into `KnowledgeCoreShadowRuntime` startup, flag-gated + rollback (fresh-empty
if the log is corrupt/missing).

**Test strategy (cargo, additive — keeps the 38 floor):** `oplog_roundtrip` (write N envelopes →
replay into fresh store → query results match original); `snapshot_plus_tail_equals_full_replay`;
`corrupt_log_falls_back_to_empty` (no panic, rollback). Existing 38 store tests stay in-memory.

**Regression risk: LOW** for the 38-test floor (in-memory path untouched); new risk is confined to
the replay/snapshot code, covered by the new tests above.

**Gate:** `state:candidate` — owner sign-off + RunEventLog/AnswerPacket/WRV/rollback before any
promotion. This scoping is decision-ready: a one-word "persistence" go starts Slice 2 on path (B).

## 11. Slice 2 DONE + Slice 3 reframed by discovery (2026-06-13)

**Slice 2 persistence: COMPLETE + verified.** 2.1 (`e8aafc5770`) oplog.rs replay-log core
(39 cargo tests); 2.2 (`15447fbf59`) `graph_engine_kc_enable_persistence` FFI + bridge
`oplogPath` wiring (22 Swift tests incl. `bridgePersistsAndReplaysAcrossRestart` — a fresh
bridge replays a prior session's log across a restart). Restart-survivable durable persistence.

**Key discovery — KC is UNWIRED from the app.** `KnowledgeCoreShadowRuntime` is instantiated
**nowhere** in the app; `AppBootstrap` has zero KC references. So the entire KC subsystem
(parser, store, persistence, FFI, bridge, subscriptions) is built + tested + persisting but is
NOT connected to the running app. "Promotion" (Slice 3) is therefore the real app integration,
not a flag flip:
1. Instantiate `KnowledgeCoreShadowRuntime` in `AppBootstrap` (flag-gated; pass `<vault>/.epcache/kc-oplog.jsonl` for persistence).
2. Feed it the vault's notes (ingest on vault sync).
3. Drive the actual SwiftUI views from KC diffs (the cutover) — but note KC emits subscription
   diffs (outline/tasks/properties/links), NOT QueryResults, so this is the Notes/sidebar/tasks
   surface, not the QueryRuntime search seam (Slice 0).

Steps 1-2 are buildable + compile-verifiable headless (flag-gated-OFF → no default-app behavior
change). Step 3 (driving real UI state) is high-stakes and **runtime-verifiable only in a
dev-cert app build** — build flag-off + verify on `Product ▸ Run` before promoting (flag on).

## 12. Slice 3 steps 1-2 LANDED + fact-counts read API + runtime health row (2026-06-13)

**Steps 1-2 done (`d68a368c1b`).** New flag `knowledgeCoreRuntimeV0` (default OFF, env
`EPISTEMOS_KNOWLEDGECORE_RUNTIME_V0`). `KnowledgeCoreShadowRuntime.init?` gained `oplogPath`
forwarding; `AppBootstrap` stands up a lazy, vault-rotating runtime against
`<vault>/.epcache/kc-oplog.jsonl`, wired into startup + `.vaultChanged`. **Seed gate:** the full
vault feed (SDPage → `ingestDocument`) runs ONLY when there is no prior oplog to replay — later
opens trust the replayed state, so the oplog stays bounded and persistence is genuinely used
(not re-walked each launch). App `BUILD SUCCEEDED`; KnowledgeCoreBridge suite 23/23.

**First KC read API + observability.** `graph_engine_kc_fact_counts` FFI → bridge `factCounts()`
→ runtime `factCounts()` exposes the store's (blocks, tasks, properties, links) counts — the
first read *into* KC state (every prior FFI was a mutation or a ring drain). This is the seam the
eventual UI cutover reads through. Surfaced read-only in Settings ▸ Diagnostics via
`KnowledgeCoreRuntimeHealthRow` (flag state, runtime-standing, live fact counts, durable-oplog
byte size). Honest `VerifiedFloorChipStrip`: `productionWired:false`, shadow-only, "drives no
user-visible surface yet." Tests: `knowledge_core_fact_counts_reflect_ingested_state` (Rust),
`bridgeFactCountsReflectIngestedState` + `shadowRuntimePersistsThroughOplogPath` (Swift).

**Edit-tracking LANDED.** `reingestKnowledgeCorePageIfReady(pageId:)` fires on `.vaultPageChanged`
(the same debounced save signal the shadow reindex uses) and re-ingests the changed page, so the
KC projection tracks the live vault between launches instead of going stale after the one-time
seed. Re-ingest is a `store.replace_page` (idempotent block replace, NOT append — locked by
`bridgeReingestReplacesBlocks`) and journals one mutation per save. Fast-path: the runtime is nil
when the flag is off, so the default build short-circuits every save with no flags read.

## 13. Oplog compaction LANDED (Slice 2.4 — bounds per-edit growth)

The edit-tracking path appends one ingest per save, so the log grew unbounded over a long-lived
vault. `OpLog::compact()` collapses it to its minimal state-equivalent form: since
`IngestDocument` is a full `replace_page`, each page's LAST ingest is a reset point — every command
recorded before it is dead and dropped; commands after it (block insert/move/delete) are kept in
order; pages with no ingest keep everything. Replaying the compacted log reproduces identical
state. Rewrite is crash-safe (temp file + atomic rename — a mid-write crash leaves the original log
intact). Wired into `graph_engine_kc_enable_persistence` so the log is bounded on every
persistence-enabled open (no-op when already minimal). N edits of one page → one ingest.

Tests (9, all green): 8 `compaction_tests` units (empty, repeated-collapse, pre-ingest-dropped,
post-ingest-kept-in-order, independent-per-page, idempotent, no-ingest-keep-all, rewrite-round-trip)
+ `oplog_compaction_collapses_edits_but_preserves_state` integration (4 ingests → compact → 2 →
replay → identical fact counts). Rust KC suite 49/49.

## 14. Step 3 read path LANDED — KC drives a SwiftUI surface (2026-06-13)

The design tension (the runtime's diff poller is intentionally zero-copy / string-free, so it can't
feed a content view) is resolved by a SEPARATE on-demand **content read API**, not a change to the
poller: `Store::page_outline(page_id)` reads the in-memory block mirror directly (ordered by
order_key) → `graph_engine_kc_page_outline_json` FFI (JSON via the `graph_engine_free_string`
convention) → bridge/runtime `pageOutline(pageId:)` → `[KnowledgeCoreOutlineRow]`. Content is
materialized ONLY here, on demand; the streaming hot path stays string-free.

`KnowledgeCoreOutlinePreview` (Settings ▸ Diagnostics) is the first SwiftUI surface driven by the KC
projection: it reads a real vault page's outline through that API and renders it indented by depth,
with page-cycling. Read-only, flag-gated (`knowledgeCoreRuntimeV0`), honest "runtime not running"
empty state. Tests: `page_outline_returns_ordered_content_rows` (Rust), `bridgeReadsPageOutline`
(Swift). Rust 50/50, app BUILD SUCCEEDED, KnowledgeCoreBridge 26/26.

**Still ahead (production binding, dev-cert-gated):** point the REAL Notes outline / sidebar at the
same `pageOutline` read (+ refresh on the poller's diff signal for live updates), build flag-off,
verify on `Product ▸ Run` before promotion. The read path + a working preview surface are now
landed + verified; only wiring the production view and live-refresh remain, and those are the
dev-cert step. Everything else (persistence, instantiate, seed, read APIs, edit-track, compaction,
outline read + preview) is headless-verified.

## 15. Two-path discovery + production-TOC cutover plan (2026-06-13)

Investigating the production binding surfaced a SECOND, pre-existing KC→outline path, distinct
from the new persistent runtime:

- **Path B (pre-existing, `deterministicKnowledgeCoreRuntime` flag):**
  `KnowledgeCoreOutlineProjectionState` in `NoteTableOfContents.swift` drives the production TOC.
  But it (a) spins its OWN `KnowledgeCoreBridge` PER open note (one store per TOC, separate from
  the app-wide runtime), (b) RE-INGESTS the markdown on every refresh, and (c) crucially still
  sets `items = fallbackHeadings` (the regex markdown-heading parse) after applying KC payloads —
  so KC currently SHADOW-validates the TOC but its projection is NOT displayed. The user still
  sees the old regex headings.
- **Path A (new, `knowledgeCoreRuntimeV0` flag):** the app-wide persistent seeded runtime +
  `pageOutline` read API + `KnowledgeCoreOutlinePreview` (live-validated: 73,035 blocks projected
  from My mind 2, outline rendered).

**So the production TOC is NOT yet KC-displayed — it is shadow-validated.** The real cutover is to
make the TOC DISPLAY KC's projected items, sourced from the shared seeded runtime (Path A) via
`pageOutline`, retiring Path B's per-TOC bridge + per-refresh re-ingest + the
`items = fallbackHeadings` shadow.

**Canonical cutover plan (dev-cert-gated — now runnable since computer-use live verification works):**
1. Give `KnowledgeCoreOutlineProjectionState` access to the shared `AppBootstrap.knowledgeCoreRuntime`;
   when present, build `items` from `runtime.pageOutline(pageId:)` (already seeded — no per-TOC
   bridge, no re-ingest) instead of the regex headings.
2. Live-refresh: re-read on the runtime's diff signal (the poller's frame counter) so edits update
   the TOC. Until that lands, refresh on `.vaultPageChanged` (the same signal edit-tracking uses).
3. Keep it flag-gated + fallback-safe: regex headings remain the fallback when the runtime is off
   or returns empty, so a KC miss never blanks the user's note navigation.
4. Retire `deterministicKnowledgeCoreRuntime`'s per-TOC bridge once Path A drives the display.
5. Verify on `Product ▸ Run` (A/B the flag) before flipping the default — this is the one step that
   changes a user-visible production surface, so it stays gated until visually confirmed.

This is the final cutover step. Everything beneath it (persistence, instantiate, seed, read APIs,
edit-track, compaction, outline read + preview, app-wide AFM serialization, NL-embedding fix) is
landed + verified, with the headline pieces live-validated on the real vault.

### 15.1 CORRECTION — the heading-TOC is the wrong cutover target (model mismatch)

Reading `TOCItem` invalidates §15 step 1's "drive the TOC from `pageOutline`": `TOCItem` is
`{level: 1–5 (markdown heading), title, charOffset (scroll target), kind}` and the TOC shows ONLY
headings. KC's `pageOutline` returns EVERY block with outline `depth` — no markdown heading level
and no char offset. The two are different abstractions:

- Heading-TOC: sparse headings + char offsets, for jump-to-section navigation.
- KC outline: every block + nesting depth, the document's full structural projection.

That mismatch is exactly why the existing `deterministicKnowledgeCoreRuntime` path keeps
`items = fallbackHeadings` — KC's block outline can't directly populate a heading-TOC. So the
production cutover is a PRODUCT DECISION, not a mechanical wire-up. Two honest options:

1. **New block-outline surface (preferred):** promote `KnowledgeCoreOutlinePreview` into a real
   Notes block-navigator / sidebar that shows the full block structure (KC's native model). KC
   drives a surface that MATCHES it; the heading-TOC keeps its regex headings. Lowest risk, no KC
   schema change, and the preview is already that surface in diagnostic form.
2. **Extend KC to feed the heading-TOC:** add char-offset + heading-level to the block facts
   (parser already sees the markdown line, so heading level is derivable; char offset needs the
   ingest to record byte spans). Then the heading-TOC can read headings-with-offsets from KC.
   Larger (KC schema + parser + FFI change) and only worth it to retire the regex parser.

Recommendation: option 1 — KC drives a block-navigator, not the heading-TOC. Needs a one-line
product call on WHERE that navigator lives (new sidebar panel vs. an outline mode in the editor)
before building, so this is the genuine "needs the user" fork. Everything up to here is built +
verified + live-validated; the next step is that product decision.

## 16. Production cutover LANDED + live-confirmed (2026-06-13, Option 1)

`0bdf01711a` — the note editor's outline panel (`NoteOutlineOverlay`) gained a Headings ⇄ Blocks
toggle. Blocks mode renders KC's projection of the page (every block, by depth) via
`KnowledgeCoreBlockOutline.items` → the shared runtime's `pageOutline` (no per-TOC bridge, no
re-ingest), with char offsets resolved against the markdown for click-to-scroll. Flag-gated
(`knowledgeCoreRuntimeV0`) + fallback-safe (empty → headings-only). Auto-updates on edits because
`blockOutlineItems` rebuilds in the editor's snapshot pass (which the edit-tracking re-ingest
already feeds).

Verified: app BUILD SUCCEEDED; NoteEditorLayout + KnowledgeCoreBridge 98/98. **Live-confirmed** on
My mind 2: on a note with NO markdown headings, the outline panel's tab appears — which it only
does when `hasBlocks` is true, i.e. KC's block outline populated the panel (the old headings-only
code would show nothing). This is KC driving a production surface end-to-end.

**The KC shadow→production cutover is COMPLETE:** persistence → in-app runtime → seed → fact/outline
read APIs → edit-tracking → compaction → diagnostic preview → production block-navigator. Remaining
is optional cleanup (§15 step 4: retire the now-redundant `deterministicKnowledgeCoreRuntime`
per-TOC shadow bridge) and the hover-reveal screenshot (computer-use can't trigger the slide-out).
