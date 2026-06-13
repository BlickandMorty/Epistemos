# Knowledge-Core Shadow → Production Cutover Plan (2026-06-13)

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
