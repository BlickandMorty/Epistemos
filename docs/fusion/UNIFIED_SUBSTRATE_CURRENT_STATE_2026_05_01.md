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
- AgentEvent PR4 now has HookRegistry API-level lifecycle emission. Registering
  and firing hooks persists tool-less `hook_registered`, `hook_fired`, and
  `hook_completed` rows with non-empty run ids, hook ids, hook points, source
  metadata, and completion outcome metadata. This preserves hook ordering and
  cancellation semantics and does not claim production hook call-site mounting.
- AgentEvent PR5 now has read-only Settings visibility. EventStore exposes
  bounded `agentEventDiagnostics()` for total rows, distinct runs, distinct
  tools, latest event, and last kind, and Settings mounts
  `AgentEventVisibilityRow` as a diagnostic-only surface without repair,
  emission, routing, OpLog, GraphEvent, graph renderer, retrieval, Halo,
  Theater, Rust, or generated-binding side effects.
- Sovereign Gate Core PR1 now has the single Swift authorization executor:
  `Epistemos/Sovereign/SovereignGate.swift` is the only production source that
  imports `LocalAuthentication` or instantiates `LAContext`. It executes
  externally supplied `.none`, `.biometric(category:graceDuration:)`, and
  `.deviceOwnerAuthentication` requirements with category-scoped Sensitive
  grace, explicit grace clearing, empty-reason denial, failed-auth denial, and
  clock-rollback / invalid-duration hardening. It does not implement the Rust
  action-class matrix, generated UniFFI transport, Secure Enclave sealing,
  Pro/Research Sovereign class, or existing popup migrations.
- Sovereign Gate Lifecycle PR2 is now closed for app-owned grace hygiene:
  `AppBootstrap` owns one shared `SovereignGate`, starts/stops
  `SovereignGateLifecycleObserver`, and clears Sensitive grace on app
  resign-active, app hide, workspace sleep, session resign-active, and screen
  sleep. It does not migrate existing confirmation dialogs, decide action
  classes in Swift, touch Rust/generated transport, or add Pro/Research routes.
- R16 Sidecar Schema Mirror Card 2 is closed as a docs-only audit/no-op for
  code. A refreshed Rust/Swift audit found no active Rust reader or writer for
  note `<stem>.epistemos.json` sidecars, so Swift remains the active contract
  source through `EpistemosSidecarStore` and no Rust mirror should be invented
  without a new exact gate and v2/v3/additive-field parity fixtures.
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
- Durable GraphEvent projection snapshot PR3 is now closed. EventStore exposes
  bounded `recentGraphEvents(limit:)` for the latest durable graph-event window
  in chronological projection order, and `DurableGraphEventProjection` folds
  durable rows into deterministic read-only node/edge snapshots without graph
  renderer, retrieval, Halo, Theater, Rust, OpLog, or UI side effects.
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
  `/tmp/epistemos-agent-event-hook-pr4-green-eventstore-20260501.log`,
  and
  `/tmp/epistemos-agent-event-hook-pr4-green-runtime-20260501.log`,
  and
  `/tmp/epistemos-graph-event-pr1-green-20260501-r1.log`,
  and
  `/tmp/epistemos-graph-event-visibility-pr2-final-20260501.log`,
  and
  `/tmp/epistemos-graph-event-projection-pr3-green-20260501.log`,
  and
  `/tmp/epistemos-sovereign-gate-pr2-green-20260502-r2.log`,
  and
  `/tmp/epistemos-r16-sidecar-schema-swift-green-20260502.log`.
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
emission paths closed plus HookRegistry API-level lifecycle emission and
read-only Settings visibility. It is not yet production hook call-site mounting.
`graph_events` is now the durable Swift source for mutation-derived graph
provenance with a read-only projection snapshot fold. The next provenance gates
are Omega/broader runtime AgentEvent coverage, production hook call-site
mounting, GraphEvent projection into live graph/retrieval/Halo/Theater surfaces,
incremental replay/export, and deeper audit/repair surfaces beyond the current
read-only Settings diagnostics, projection snapshot replay, chain verification,
AgentEvent visibility diagnostics, and GraphEvent visibility/projection
diagnostics.

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
  Rust agent sessions. HookRegistry lifecycle APIs now emit tool-less
  registered/fired/completed rows for existing hook calls.
- Settings diagnostics now expose read-only durable AgentEvent visibility from
  EventStore, including total row count, distinct run count, distinct tool
  count, latest event metadata, and last event kind.
- EventStore now persists mutation-derived durable graph provenance in
  `graph_events` through `DurableGraphEvent` and bounded GraphEvent read APIs;
  committed graph-affecting mutation envelopes emit deterministic rows
  transactionally with envelope/outbox persistence.
- Settings diagnostics now expose read-only durable GraphEvent visibility from
  EventStore, including total row count, distinct mutation count, latest event
  metadata, and last event kind.
- EventStore now exposes read-only recent durable GraphEvent windows, and
  `DurableGraphEventProjection` can fold those rows into deterministic
  node/edge snapshots for future graph, retrieval, Halo, Theater, or audit
  consumers.
- R15 benchmark JSON recorder foundation is now present for the existing manual
  benchmark suites, with a tested schema and non-shipping
  `benchmarks/results/` output path. R15 PR2 also adds real fixture baselines
  for Swift graph payload construction, markdown parser FFI, and code-token
  parser FFI, with three deterministic JSON reports under
  `benchmarks/results/`. R15 PR3 adds a real AppKit/TextKit editor-shell
  fixture baseline without touching production editor files. R15 PR4 adds a
  real sqlite-vec `vec0` KNN baseline at 100k deterministic 32-dimensional
  vectors, with p50/p95/p99 JSON output and no production GRDB/search claim.
  R15 PR5 adds a generated UniFFI `AgentEventDelegate` callback-handle
  lowering/lifting baseline with p50 332.35 ns/call, p95 354.97204 ns/call,
  and metadata explicitly marking it as not the future true Rust-to-Swift
  callback-loop export. R15 PR6 adds an MLX dispatch backpressure policy
  fixture over `PowerGate.deferSnapshot`, with p50 206.375 ns/decision, p95
  229.9998 ns/decision, p99 235.46635999999998 ns/decision, and metadata
  explicitly marking it as `not_live_mlx_inference_tok_s`. R15 PR7 adds a live
  `GraphEngine`/C FFI bridge fixture baseline over a 250-node deterministic
  graph, with p50 68,846,708 ns/fixture roundtrip, p95 100,320,625 ns/fixture
  roundtrip, p99 102,145,625 ns/fixture roundtrip, and metadata explicitly
  marking it as `not_live_render_frame_rate`.
- R16 background indexing has visible diagnostics, ETL stats/dispatch plumbing,
  AFM sidecar generation, memory-pressure-aware dispatch pause semantics,
  MAS/security-scoped bookmark enforcement, model-derived badge visibility, and
  honest ETL worker execution through the approved PR3 slices. ETL jobs now
  reach `done` only after the Rust worker re-validates file existence,
  readability, byte length, input kind, and fingerprint.
- R16 sidecar schema mirror Card 2 is closed as audit-only: active sidecar
  reads/writes are Swift surfaces, optional AFM fields remain additive, and no
  Rust note-sidecar mirror exists to patch.
- V0 Contextual Shadows is production-mounted and now prefers the configured
  per-vault `ShadowSearchService` backend when the Shadow backend is ready,
  while preserving the `InstantRecallService` fallback. Recall cards carry
  visible source provenance.
- V1 Halo controller/editor bridge/search panel scaffolding exists and is
  tested, but is not production-mounted.
- Hermes Cloud Gateway architecture is now doc-locked: Pro/Research cloud
  models, MCP/web/browser tools, Docker/devcontainer work, and
  Claude/Codex/Kimi/Gemini CLI delegation use one unified gateway/control
  surface. Concrete adapters can be gated in-process Rex/provider paths or a
  Hermes subprocess adapter. Hermes is not Rex, not the graph, and not the
  deterministic substrate; structured evidence returns through typed artifacts,
  mutation envelopes, and gates.

Still open:

- Incremental replay, ReplayBundle export, and mutating rollback/repair
  semantics beyond read-only projection snapshots and read-only chain
  verification.
- Omega, production hook call-site mounting, and broader agent runtime
  `AgentEvent` emission beyond the PipelineService observed-tool,
  ChatCoordinator Rust-stream, and HookRegistry API-level paths.
- Live GraphEvent consumer projection beyond durable mutation mapping,
  read-only Settings visibility, and the read-only projection snapshot, such
  as graph, retrieval, Halo, Theater, or audit surfaces.
- Sovereign Gate follow-through beyond the Core Swift executor: Rust-side
  action-class matrix, generated transport, existing confirmation-surface
  migration, and any Pro/Research Secure Enclave or Sovereign-class routes.
- Deeper audit trail and repair UX beyond read-only projection diagnostics.
- Full V1 Halo editor mount, trailing-edge editor glyph, and inline editor
  integration remain separate protected-path decisions.
- R15 remaining specialized baselines before any graph-engine/FFI optimization:
  live MLX token throughput under thermal soak and the true Rust callback-loop
  export. Any production GRDB/768-dimensional KNN claim still needs its own
  later fixture gate.
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
   PR5 is closed for generated UniFFI callback-handle lowering/lifting only.
   PR6 is closed for `PowerGate.deferSnapshot` MLX thermal policy/backpressure
   decisions only. PR7 is closed for live `GraphEngine`/C FFI bridge fixture
   roundtrips only. Live MLX token throughput under thermal soak, live renderer
   FPS/optimization, and the true Rust callback-loop export remain later
   runtime/generated-transport gates.
   Before modifying graph-engine, graph rendering, BoltFFI, live MLX inference,
   production KNN, or any hot path beyond those surfaces, run a new fixture gate
   that writes real JSON results and promotes `try?` recorder calls only when the
   benchmark becomes authoritative.

3. **R16 runtime/manual closure.**
   ETL worker execution is closed as PR3H. Memory-pressure dispatch pause is
   closed as PR3E, MAS bookmark enforcement is closed as PR3F, and
   model-derived badge visibility is closed as PR3G, and Sidecar Schema Mirror
   Card 2 is closed as audit-only/no-code because no Rust note-sidecar mirror
   exists. Do not claim full R16 product readiness until a separate
   runtime/manual gate verifies the user flow against a real vault and records
   logs.

4. **OpLog provenance hardening.**
   Lease/retry PR3A, dead-letter PR3B, worker scheduling PR3C, read-only
   visibility PR3D, replay snapshot PR4A, AgentEvent persistence PR1,
   OpLog chain verification PR4B, AgentEvent PipelineService live tool
   provenance PR2, AgentEvent ChatCoordinator Rust-stream PR3, AgentEvent
   HookRegistry lifecycle PR4, durable GraphEvent mutation mapping PR1,
   durable GraphEvent Settings visibility PR2, and durable GraphEvent
   projection snapshot PR3 are closed. Add Omega/broader
   runtime AgentEvent coverage, production hook call-site mounting,
   incremental replay/export, live GraphEvent consumer projections, or mutating
   repair/audit surfaces only after a new gate names the exact EventStore,
   OpLog, worker, runtime, and visibility files.

5. **Core/MAS release split audit.**
   Sovereign Gate Core PR1 is closed for the single Swift executor. Future
   Sovereign slices must start from
   `docs/fusion/deliberation/sovereign_gate_core_pr1_deliberation_2026_05_02.md`
   and may only add Rust action classification, generated transport, lifecycle
   follow-up, or existing confirmation migrations behind new exact gates. Also
   ensure Pro tunnels, Hermes, CLI passthrough, browser/computer-use, Docker,
   and external subprocess surfaces cannot leak into the Core/App Store build.
   For Pro/Research, Hermes/gateway is the cloud/tool control surface; direct
   CLIs are delegated tools behind it, not separate app architectures or graph
   authorities.

6. **V1.5 typed artifacts and Pro tunnels.**
   Only after the Core provenance/retrieval/diagnostics substrate is stable.

## What Agents Can Start Now

Agents are good to work on narrow, gated cards only. The safest immediate cards
are:

- Card 5 Halo Live Loop follow-up, but only for the remaining full V1/editor
  mount work behind a protected-path gate. The V0 Shadow backend route PR1 is
  already closed.
- Raw Thoughts / Provenance Spine Hardening, now starting after PR3B,
  AgentEvent PR4, GraphEvent PR1, GraphEvent visibility PR2, and GraphEvent
  projection snapshot PR3 with
  Omega/broader runtime AgentEvent coverage, production hook call-site mounting,
  live GraphEvent consumer projections, incremental replay/export, deeper repair/audit
  visibility, and trace/audit projection semantics.
  Background worker scheduling is closed as PR3C, basic read-only Settings
  visibility is closed as PR3D, read-only projection replay snapshots are
  closed as PR4A, read-only OpLog chain verification is closed as PR4B, durable
  AgentEvent persistence is closed as PR1, PipelineService observed tool
  lifecycle emission is closed as PR2, ChatCoordinator Rust-stream lifecycle
  emission is closed as PR3, HookRegistry API-level lifecycle emission is
  closed as PR4, durable GraphEvent mutation mapping is closed as PR1,
  read-only GraphEvent Settings visibility is closed as PR2, and read-only
  GraphEvent projection snapshots are closed as PR3.
- R15 Benchmark Harness PR2/PR3/PR4/PR5/PR6/PR7 real fixture baselines are closed
  for Swift graph payload construction, markdown parser FFI, code-token parser
  FFI, editor-shell AppKit/TextKit work, sqlite-vec 100k x 32d KNN, generated
  UniFFI callback-handle lowering/lifting, and MLX thermal policy/backpressure
  decisions, and live `GraphEngine`/C FFI bridge roundtrips. Remaining R15
  baseline work stays benchmark/test-only until a fixture gate explicitly names
  any production path.
- R16 follow-up only for runtime/manual verification, throughput/backfill, or
  sidecar-generation expansion behind a new exact gate. Memory-pressure
  dispatch pause is closed as PR3E, MAS bookmark enforcement is closed as PR3F,
  model-derived badge visibility is closed as PR3G, and ETL worker execution is
  closed as PR3H. Do not assign Card 2 sidecar mirror work unless a new gate
  first introduces an actual Rust note-sidecar mirror target.
- Sovereign Gate follow-up only for exact gated slices after Core PR1: Rust
  action classification, generated requirement transport, lifecycle follow-up
  beyond PR2's app/session/sleep grace clearing, or migration of existing confirmation
  surfaces to `SovereignGate`.

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
foundation, R15 PR2/PR3/PR4/PR5/PR6/PR7 real fixture baselines, EventStore OpLog
lease/retry PR3A, EventStore OpLog dead-letter PR3B, EventStore OpLog worker scheduling PR3C,
EventStore OpLog read-only visibility PR3D, EventStore OpLog replay snapshot
PR4A, EventStore OpLog chain verification PR4B, AgentEvent durable persistence
PR1, AgentEvent PipelineService live tool provenance PR2, AgentEvent
ChatCoordinator Rust-stream PR3, AgentEvent HookRegistry lifecycle PR4,
AgentEvent Settings visibility PR5, durable GraphEvent mutation mapping PR1,
durable GraphEvent Settings visibility PR2, durable GraphEvent projection snapshot PR3,
Sovereign Gate Core PR1, Sovereign Gate Lifecycle PR2, the Halo V0 Shadow
backend route, R16 memory-pressure dispatch pause PR3E, and R16 MAS bookmark
enforcement PR3F, R16 model-derived badge visibility PR3G, and R16 ETL worker
execution PR3H, plus the R16 Sidecar Schema Mirror Card 2 audit/no-op closure,
are good to build on.
The next best build card is either live GraphEvent consumer projection,
Omega/broader runtime AgentEvent coverage,
production hook call-site mounting, Sovereign Gate Rust/transport/surface
follow-through, remaining
R15 specialized baselines, R16 runtime/manual closure, or a protected V1 Halo
editor gate, depending on whether the immediate priority is provenance
projection, security/policy gating, performance-safe graph/FFI work,
background retrieval, or richer recall UX.
