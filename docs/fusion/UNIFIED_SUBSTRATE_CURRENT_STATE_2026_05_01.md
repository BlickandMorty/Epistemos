# Unified Substrate Current State - 2026-05-01

## Verdict

The April 30 substrate doctrine is still the right north star:

> Epistemos is a native macOS verifiable cognition substrate where every
> meaningful action becomes a typed, provenance-linked event before it becomes
> a UI effect.

That is the most direct and durable reading of the research. The profound part
is not another model wrapper, agent shell, or feature branch. The profound part
is the substrate law:

```text
TypedArtifact
  -> MutationEnvelope
  -> RunEventLog / AgentEvent / GraphEvent
  -> Retrieval / Halo / Graph / Theater / Audit projections
```

This is the optimization target: make models, tools, notes, files, graph
updates, captures, and future agents operate through one deterministic,
policy-gated, observable provenance spine.

## What Changed Since The April 30 Master Plan

The master plan's Quick Capture section is now partly ahead of the text.

Card 4's minimal typed-artifact slice is already current:

- Quick Capture sheet routes through `TextCapturePipeline`.
- Audio capture routes through `TextCapturePipeline.runFromAudio`.
- `QuickCaptureIntent` routes through `bootstrap.textCapturePipeline`.
- Sheet/audio/shortcut success requires a persisted note and
  `mutationEnvelopePersisted`.
- `TextCapturePipeline` constructs a committed prose-note `MutationEnvelope`.
- `EventStore.saveMutationEnvelope(_:traceId:)` persists the envelope and
  projection outbox metadata.
- Focused tests passed:
  `/tmp/epistemos-quick-capture-typed-artifact-text-capture-tests-20260501.log`
  and
  `/tmp/epistemos-quick-capture-typed-artifact-mutation-envelope-parity-tests-20260501.log`.
- Kimi independently confirmed the read-only Card 4 audit in
  `/tmp/epistemos-quick-capture-typed-artifact-kimi-advisory-20260501.log`.

Therefore, agents should not rebuild a parallel Quick Capture scaffold for the
minimal vertical slice. They may only continue Quick Capture through new gates
for future donor ideas such as universal undo, route capture, review/defer,
semantic cache, and heal loops.

The Raw Thoughts / provenance section now has several narrow foundation slices
closed:

- Rust `OpLog` exposes bounded raw ABI functions for open, append payload JSON,
  chain-tip hex, iterate, iterate-all, release, and string free.
- Swift `RustOpLogFFIClient` owns the handle, releases it in `deinit`, frees
  Rust strings, and has no production call site yet.
- `MutationOpLogProjector` mirrors committed `MutationEnvelope` outbox rows into
  OpLog as append-only `mutation_projection` payloads and marks rows with
  `oplog_seq` / `projected_at`.
- Projection is idempotent across append-before-mark retry: if the OpLog row
  already exists, EventStore marks the existing sequence without duplicating.
- EventStore OpLog projection now has deterministic lease/retry primitives:
  owner-scoped claims, finite lease deadlines, retry deadlines, attempt counts,
  bounded last-error strings, and owner-guarded projection marking so stale
  workers cannot clear newer claims.
- EventStore OpLog projection now has bounded dead-letter primitives:
  max-attempt failure recording, dead-letter timestamp/reason metadata,
  claim/pending exclusion for dead-lettered rows, bounded last-error visibility,
  and explicit projection repair that clears dead-letter metadata.
- EventStore OpLog projection now has a finite production scheduling shell:
  `MutationOpLogProjectionWorker` lazily opens the app-scoped OpLog database,
  coalesces scheduled drains, delegates projection semantics to
  `MutationOpLogProjector`, and is scheduled once from AppBootstrap deferred
  runtime services outside tests.
- EventStore OpLog projection now has bounded read-only Settings diagnostics:
  projected, pending, leased, dead-lettered, and latest dead-letter state are
  visible through EventStore without opening Rust OpLog handles or mutating
  projection rows from the UI.
- EventStore OpLog projection now has Swift-only replay snapshots:
  `MutationOpLogReplay` folds decoded OpLog projection entries into a
  deterministic read-only view, supports `upToSeq` cutoff rollback inspection,
  reports duplicate projections, and can be reached through
  `RustOpLogFFIClient.replayMutationProjections(upToSeq:)` without new raw ABI.
- Rust OpLog chain verification PR4B is now closed. `OpLog::verify_chain`
  recomputes the BLAKE3 chain from genesis, validates contiguous sequence
  numbers and persisted `prev_hash` continuity, compares recomputed and stored
  tips, and optionally anchors against an externally supplied expected tip.
  Swift exposes this through `RustOpLogFFIClient.verifyChain(expectedTipHex:)`
  without generated binding edits or production UI changes.
- AgentEvent/tool provenance now has a durable Swift EventStore foundation:
  `AgentProvenanceEvent` encodes lower-snake-case run/tool provenance JSON, the
  `agent_events` table enforces unique `event_id`, and EventStore exposes
  bounded save/load/list APIs.
- AgentEvent/tool provenance PR2 now has live PipelineService emission at the
  `observedToolExecutor(...)` chokepoint: requested, approved/denied, started,
  and completed/failed lifecycle events are persisted for local observed tool
  execution without changing approval, execution, UI, streaming, or routing
  semantics.
- AgentEvent/tool provenance PR3 now has live ChatCoordinator Rust stream
  emission at both Rust `AgentStreamEvent` consumers: Command Center and managed
  chat persist permission requested/approved/denied plus tool
  started/completed/failed rows without changing approval, execution, UI,
  streaming, routing, Rust bindings, OpLog, GraphEvent, Omega, hooks, or
  generated files.
- Durable GraphEvent mutation mapping PR1 is now closed. EventStore has a
  `graph_events` table and bounded `saveGraphEvent(_:)`,
  `loadGraphEvent(eventID:)`, and `graphEvents(mutationID:limit:)` APIs.
  Committed graph-affecting `MutationEnvelope`s now persist deterministic
  `DurableGraphEvent` rows in the same SQLite transaction as the envelope and
  projection outbox row; pending/failed/reverted envelopes do not emit graph
  events. The Swift model is intentionally named `DurableGraphEvent` because
  `EventDrain.swift` already owns the 64-byte FFI `GraphEvent` ring event.
- Durable GraphEvent visibility PR2 is now closed. EventStore exposes bounded
  read-only `graphEventDiagnostics()` for total rows, distinct mutations,
  latest graph event, and last kind. Settings mounts `GraphEventVisibilityRow`
  as a read-only diagnostic without repair, projection, graph renderer,
  retrieval, Halo, Theater, or Rust OpLog side effects.
- Focused tests passed:
  `/tmp/epistemos-oplog-swift-bridge-pr1-cargo-test-final-20260501.log`,
  `/tmp/epistemos-oplog-swift-bridge-pr1-final2-xcode-20260501.log`,
  `/tmp/epistemos-eventstore-oplog-projection-cargo-test-post-kimi-20260501.log`,
  `/tmp/epistemos-eventstore-oplog-projection-green-suite-post-kimi-20260501.log`,
  `/tmp/epistemos-eventstore-oplog-projection-bridge-boundary-post-kimi-20260501.log`,
  `/tmp/epistemos-oplog-lease-retry-pr3a-green-20260501.log`,
  and
  `/tmp/epistemos-oplog-dead-letter-pr3b-green-2-20260501.log`,
  `/tmp/epistemos-oplog-worker-pr3c-green-20260501.log`,
  `/tmp/epistemos-oplog-worker-pr3c-boundary-20260501.log`,
  `/tmp/epistemos-oplog-visibility-pr3d-focused-2-20260501.log`,
  `/tmp/epistemos-oplog-replay-pr4a-green-20260501.log`,
  `/tmp/epistemos-oplog-chain-verify-pr4b-green-cargo-20260501-r1.log`,
  `/tmp/epistemos-oplog-chain-verify-pr4b-green-xcode-20260501-r1.log`,
  and
  `/tmp/epistemos-agent-event-pr1-green-20260501.log`,
  and
  `/tmp/epistemos-agent-event-pr2-combined-green-20260501-r3.log`,
  and
  `/tmp/epistemos-agent-event-pr3-green-20260501-r1.log`,
  and
  `/tmp/epistemos-graph-event-pr1-green-20260501-r1.log`,
  and
  `/tmp/epistemos-graph-event-visibility-pr2-final-20260501.log`.
- Kimi found no P0/P1 blockers in
  `/tmp/epistemos-oplog-swift-bridge-pr1-kimi-advisory-fallback-20260501.log`
  `/tmp/epistemos-eventstore-oplog-projection-kimi-final-advisory-20260501.log`,
  `/tmp/epistemos-oplog-lease-retry-pr3a-kimi-advisory-20260501.log`, or
  `/tmp/epistemos-oplog-dead-letter-visibility-kimi-advisory-2-20260501.log`,
  `/tmp/epistemos-oplog-replay-pr4a-kimi-advisory-20260501.log`, or
  `/tmp/epistemos-agent-event-pr1-kimi-advisory-20260501.log`, or
  `/tmp/epistemos-agent-event-pr2-kimi-advisory-20260501.log`.
- PR3B's Kimi read-only audit produced no output and was terminated; PR3B
  closes on Codex red/green tests and guardrails rather than Kimi approval.
- AgentEvent PR3's Kimi read-only audit also produced no output after several
  minutes and was terminated; PR3 closes on Codex red/green tests and guardrails
  rather than Kimi approval.
- GraphEvent PR1's Kimi read-only audit produced no output and was terminated;
  PR1 closes on Codex red/green tests and guardrails rather than Kimi approval.

This is provenance foundation, not full product event logging. EventStore remains
the committed source of truth; OpLog is now a deterministic projection target for
mutation provenance with read-only replay snapshots and cryptographic chain
verification, and `agent_events` is now the durable Swift source for agent/tool
provenance with the first PipelineService and ChatCoordinator Rust-stream live
emission paths closed. `graph_events` is now the durable Swift source for
mutation-derived graph provenance. The next provenance gates are
Omega/hook/broader runtime AgentEvent coverage, GraphEvent projection into live
graph/retrieval surfaces, incremental replay/export, and deeper audit/repair
surfaces beyond the current read-only Settings diagnostics, projection snapshot
replay, chain verification, and GraphEvent visibility diagnostics.

## Current Substrate Spine Status

Proven or actively wired:

- `MutationEnvelope` exists in Swift and Rust with parity tests.
- `EventStore` persists committed mutation envelopes and projection outbox rows.
- Quick Capture now proves the Core rule: UI success waits for durable typed
  provenance.
- Rust OpLog now has a narrow Swift-owned bridge with append, chain-tip,
  iterate, reopen, and boundary tests.
- EventStore projection outbox rows can now be mirrored into OpLog with
  append-only, restart-safe idempotency.
- EventStore projection outbox rows can now be claimed with deterministic
  owner-scoped leases and retried after bounded failure deadlines.
- EventStore projection outbox rows can now be dead-lettered at a bounded
  max-attempt threshold and excluded from future projection claims until an
  explicit repair/mark path handles them.
- A production-safe OpLog projection worker shell is now wired from
  AppBootstrap deferred runtime services, with finite coalesced drains and no
  timer or endless loop.
- Settings diagnostics now expose read-only OpLog projection health from
  EventStore, including dead-letter counts and latest dead-letter detail.
- Swift replay can fold projected mutation provenance into deterministic
  read-only snapshots and inspect logical rollback cutoffs by OpLog sequence.
- Rust OpLog chain verification can validate persisted sequence/hash continuity
  and expected-tip anchoring through the Swift-owned raw ABI bridge.
- EventStore now persists typed agent/tool provenance in `agent_events` through
  `AgentProvenanceEvent` and bounded AgentEvent read APIs; PipelineService's
  local observed tool executor now emits requested, approved/denied, started,
  and completed/failed lifecycle rows, and ChatCoordinator's Rust stream
  consumers now emit the same lifecycle rows for Command Center and managed chat
  Rust agent sessions.
- EventStore now persists mutation-derived durable graph provenance in
  `graph_events` through `DurableGraphEvent` and bounded GraphEvent read APIs;
  committed graph-affecting mutation envelopes emit deterministic rows
  transactionally with envelope/outbox persistence.
- Settings diagnostics now expose read-only durable GraphEvent visibility from
  EventStore, including total row count, distinct mutation count, latest event
  metadata, and last event kind.
- R15 benchmark JSON recorder foundation is now present for the existing manual
  benchmark suites, with a tested schema and non-shipping
  `benchmarks/results/` output path. R15 PR2 also adds real fixture baselines
  for Swift graph payload construction, markdown parser FFI, and code-token
  parser FFI, with three deterministic JSON reports under
  `benchmarks/results/`. R15 PR3 adds a real AppKit/TextKit editor-shell
  fixture baseline without touching production editor files. R15 PR4 adds a
  real sqlite-vec `vec0` KNN baseline at 100k deterministic 32-dimensional
  vectors, with p50/p95/p99 JSON output and no production GRDB/search claim.
- R16 background indexing has visible diagnostics, ETL stats/dispatch plumbing,
  AFM sidecar generation, memory-pressure-aware dispatch pause semantics,
  MAS/security-scoped bookmark enforcement, model-derived badge visibility, and
  honest ETL worker execution through the approved PR3 slices. ETL jobs now
  reach `done` only after the Rust worker re-validates file existence,
  readability, byte length, input kind, and fingerprint.
- V0 Contextual Shadows is production-mounted and now prefers the configured
  per-vault `ShadowSearchService` backend when the Shadow backend is ready,
  while preserving the `InstantRecallService` fallback. Recall cards carry
  visible source provenance.
- V1 Halo controller/editor bridge/search panel scaffolding exists and is
  tested, but is not production-mounted.

Still open:

- Incremental replay, ReplayBundle export, and mutating rollback/repair
  semantics beyond read-only projection snapshots and read-only chain
  verification.
- Omega, hook, and broader agent runtime `AgentEvent` emission beyond the
  PipelineService observed-tool and ChatCoordinator Rust-stream paths.
- GraphEvent projection beyond durable mutation mapping and read-only Settings
  visibility, such as live graph, retrieval, Halo, Theater, or audit
  projections.
- Deeper audit trail and repair UX beyond read-only projection diagnostics.
- Full V1 Halo editor mount, trailing-edge editor glyph, and inline editor
  integration remain separate protected-path decisions.
- R15 remaining specialized baselines before any graph-engine/FFI optimization:
  MLX thermal, full graph FFI, and UniFFI callback throughput. Any production
  GRDB/768-dimensional KNN claim still needs its own later fixture gate.
- MAS/Core versus Pro capability symbol separation.
- Manual runtime verification for user-facing ship claims.

## Safe Next Build Order

1. **Halo V1 implementation deliberation.**
   V0 backend routing is closed for PR1: production Contextual Shadows can use
   `ShadowSearchService` when the per-vault Shadow backend is configured and
   falls back to `InstantRecallService` otherwise. Any full V1 Halo editor mount
   still requires a protected editor gate. Do not touch `ProseEditor*` unless
   that gate explicitly approves it.

2. **R15 remaining specialized baselines.**
   PR2 real fixtures are closed for Swift graph payload construction, markdown
   parser FFI, and code-token parser FFI. PR3 is closed for editor-shell
   AppKit/TextKit fixture work. PR4 is closed for sqlite-vec 100k x 32d KNN.
   Before modifying graph-engine, graph rendering, BoltFFI, MLX, production
   KNN, or any hot path beyond those surfaces, run a new fixture gate that
   writes real JSON results and promotes `try?` recorder calls only when the
   benchmark becomes authoritative.

3. **R16 runtime/manual closure.**
   ETL worker execution is closed as PR3H. Memory-pressure dispatch pause is
   closed as PR3E, MAS bookmark enforcement is closed as PR3F, and
   model-derived badge visibility is closed as PR3G. Do not claim full R16
   product readiness until a separate runtime/manual gate verifies the user
   flow against a real vault and records logs.

4. **OpLog provenance hardening.**
   Lease/retry PR3A, dead-letter PR3B, worker scheduling PR3C, read-only
   visibility PR3D, replay snapshot PR4A, AgentEvent persistence PR1,
   OpLog chain verification PR4B, AgentEvent PipelineService live tool
   provenance PR2, AgentEvent ChatCoordinator Rust-stream PR3, durable
   GraphEvent mutation mapping PR1, and durable GraphEvent Settings visibility
   PR2 are closed. Add Omega/hook/broader runtime AgentEvent coverage,
   incremental replay/export, live GraphEvent projections, or mutating
   repair/audit surfaces only after a new gate names the exact EventStore,
   OpLog, worker, runtime, and visibility files.

5. **Core/MAS release split audit.**
   Ensure Pro tunnels, Hermes, CLI passthrough, browser/computer-use, Docker,
   and external subprocess surfaces cannot leak into the Core/App Store build.

6. **V1.5 typed artifacts and Pro tunnels.**
   Only after the Core provenance/retrieval/diagnostics substrate is stable.

## What Agents Can Start Now

Agents are good to work on narrow, gated cards only. The safest immediate cards
are:

- Card 5 Halo Live Loop follow-up, but only for the remaining full V1/editor
  mount work behind a protected-path gate. The V0 Shadow backend route PR1 is
  already closed.
- Raw Thoughts / Provenance Spine Hardening, now starting after PR3B,
  AgentEvent PR3, GraphEvent PR1, and GraphEvent visibility PR2 with
  Omega/hook/broader runtime AgentEvent coverage, live GraphEvent projections,
  incremental replay/export, deeper repair/audit visibility, and trace/audit
  projection semantics.
  Background worker scheduling is closed as PR3C, basic read-only Settings
  visibility is closed as PR3D, read-only projection replay snapshots are
  closed as PR4A, read-only OpLog chain verification is closed as PR4B, durable
  AgentEvent persistence is closed as PR1, PipelineService observed tool
  lifecycle emission is closed as PR2, ChatCoordinator Rust-stream lifecycle
  emission is closed as PR3, durable GraphEvent mutation mapping is closed as
  PR1, and read-only GraphEvent Settings visibility is closed as PR2.
- R15 Benchmark Harness PR2/PR3/PR4 real fixture baselines are closed for Swift
  graph payload construction, markdown parser FFI, code-token parser FFI,
  editor-shell AppKit/TextKit work, and sqlite-vec 100k x 32d KNN. Remaining
  R15 baseline work stays benchmark/test-only until a fixture gate explicitly
  names any production path.
- R16 follow-up only for runtime/manual verification, throughput/backfill, or
  sidecar-generation expansion behind a new exact gate. Memory-pressure
  dispatch pause is closed as PR3E, MAS bookmark enforcement is closed as PR3F,
  model-derived badge visibility is closed as PR3G, and ETL worker execution is
  closed as PR3H.

Agents should not start:

- raw Quick Capture worktree merge;
- protected editor edits;
- graph-engine optimization;
- Hermes/CLI/MCP Core integration;
- Live Files execution;
- Simulation Theater;
- neural-kernel/private ANE work.

## WRV Resume Map

Quick Capture:

- Wired: `QuickCaptureView` and `QuickCaptureIntent` call
  `TextCapturePipeline`.
- Reachable: app-scoped capture sheet, audio capture, and App Intent.
- Visible: success card/dialog only after persisted note plus durable envelope;
  trace/outbox rows prove provenance.

Contextual Shadows V0:

- Wired: production state/button/panel and note/chat/editor scheduling.
- Reachable: flag-gated `EPISTEMOS_AMBIENT_RECALL_V0=1`.
- Visible: related panel, note/chat hit rows, source provenance capsule, and
  focused tests.
- Backend: prefers configured per-vault Shadow search when ready; falls back to
  InstantRecall.
- Gap: manual runtime verification remains required before product-ready claim.

Halo V1:

- Wired: controller, editor bridge, search service, panel scaffold.
- Reachable: not production-mounted yet.
- Visible: tests only.
- Gap: needs a protected-path route decision before editor integration.

## Operating Rule For New Sessions

Start from this file, then read:

- `docs/fusion/README_START_HERE_2026_04_30.md`
- `docs/fusion/FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `/Users/jojo/Downloads/EPST_UNIFIED_SUBSTRATE_MASTER_PLAN_2026_04_30.md`
- `/Users/jojo/Downloads/CODEX_UNIFIED_EXECUTION_PROMPT_2026_04_30.md`

Then pick exactly one card, write or update a deliberation gate, run focused
tests, record raw logs, and stop at the next gate.

## Bottom Line

You can resume building now, and the substrate spine is stronger than the April
30 plan text: Quick Capture's minimal typed-artifact path, the
EventStore-to-OpLog projection foundation, the R15 JSON benchmark-recorder
foundation, R15 PR2/PR3/PR4 real fixture baselines, EventStore OpLog lease/retry PR3A,
EventStore OpLog dead-letter PR3B, EventStore OpLog worker scheduling PR3C,
EventStore OpLog read-only visibility PR3D, EventStore OpLog replay snapshot
PR4A, EventStore OpLog chain verification PR4B, AgentEvent durable persistence
PR1, AgentEvent PipelineService live tool provenance PR2, AgentEvent
ChatCoordinator Rust-stream PR3, durable GraphEvent mutation mapping PR1,
durable GraphEvent Settings visibility PR2, the Halo V0 Shadow backend route,
R16 memory-pressure dispatch pause PR3E, and R16 MAS bookmark enforcement PR3F,
R16 model-derived badge visibility PR3G, and R16 ETL worker execution PR3H are
good to build on. The next best build card is either live GraphEvent projection,
Omega/hook/broader runtime AgentEvent coverage, remaining R15 specialized
baselines, R16 runtime/manual closure, or a protected V1 Halo editor gate,
depending on whether the immediate priority is provenance projection,
performance-safe graph/FFI work, background retrieval, or richer recall UX.
