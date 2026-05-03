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

## Canon Authority Update - 2026-05-02

`docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` is now the first lookup for
any concept, feature, mini-task, worktree, or research-root question. It is the
full concept-to-source map and backlog index for the May 2 canon packet.

Operating rule:

1. Ctrl-F `MASTER_RESEARCH_INDEX_2026_05_02.md` for the concept.
2. Read the canonical source it names, not every adjacent research file.
3. Trust §0 Honest Discoveries over older docs they correct.
4. Verify against current code and fresh logs before shipping or downgrading a
   claim, because later patches may have landed after the deep-scan.

The most important §0 corrections are: Lane A is not "mostly merged" and must
be treated as 601 unmerged Prompt Tree commits; Hermes-parity currently uses
plain markdown prompts, while NousResearch ChatML is future/local-agent
formatting unless the active code path proves otherwise; Apple Intelligence
fallback is real; the agent error classifier is wired; Quick Capture has a
larger standalone canon than earlier packet text implied; six v1.6 AgentEvent
variants remain forward references; honest-handle and code-editor claims need
WRV/code checks before being called shipped; and Quick Capture tool-v2 alias
migration still has broad remaining work.

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
- OpLog ReplayBundle export PR5 is now closed. `MutationOpLogReplayBundle`
  exports replay snapshots as deterministic Codable JSON with schema/source,
  cutoff, count, record, and duplicate fields; it deliberately omits raw
  `sourcePayloadJSON` while staying read-only through
  `RustOpLogFFIClient.exportMutationReplayBundle(...)` and adding no new raw
  ABI, rollback execution, repair, UI, or scheduling path.
- OpLog incremental replay PR6 is now closed. `MutationOpLogReplay.applyIncremental(...)`
  extends read-only snapshots from tail entries, drops overlap rows before
  projection/non-projection counting, seeds duplicate detection from prior
  records, preserves PR5 ReplayBundle privacy, and
  `RustOpLogFFIClient.incrementalReplayMutationProjections(from:upToSeq:)`
  uses only the existing `iterateAll()` / `iterate(after:)` bridge surface.
- OpLog ReplayBundle production visibility PR7 is now closed.
  `MutationOpLogReplayBundleVisibilityReport` exposes bounded ReplayBundle
  counts/latest-id status for Settings, and `OpLogProjectionHealthRow` renders
  those counts without raw OpLog ABI symbols, repair/export buttons, polling,
  timers, or private `sourcePayloadJSON`/note-body leakage.
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
  Theater, or Rust/generated changes.
- AgentEvent PR6 now mounts the existing `HookRegistry` at the clean
  `PipelineService` local tool-loop boundary. Prompt-build hooks can add
  system context, local tool calls can be mutated/cancelled before approval,
  and tool results can be post-processed after execution without changing the
  no-hook behavior, approval policy, provider routing, UI, ChatCoordinator,
  Omega, graph, Rust, generated bindings, or EventStore schema.
- AgentEvent PR7 now instruments Omega ReasoningLoop internal tool calls.
  Existing internal `vault_search` / `graph_search` calls persist requested,
  started, and completed/failed AgentEvents with `reasoning-loop-...` run ids,
  `omega-reasoning-loop` actor metadata, round/tool sequence metadata, and
  bounded JSON result payloads. This does not change approval, routing, UI,
  HookRegistry, ChatCoordinator, PipelineService, graph, Rust, generated
  bindings, or EventStore schema.
- AgentEvent PR8 now instruments `CloudLLMClient.generate(...)` direct cloud
  provider calls. Non-streaming generation persists requested, started, and
  completed/failed AgentEvents with `cloud-llm-...` run ids,
  `cloud-llm-client` actor metadata, provider/model/mode metadata, and
  sanitized JSON payloads. Prompt bodies, system prompts, credentials, request
  bodies, URLs, and generated model text are intentionally excluded. This
  records the cloud-provider surface as `hermesGateway` class without changing
  provider routing, streaming, structured-output native paths, Hermes
  subprocesses, MCP, CLI, approval, UI, graph, Rust, generated bindings, or
  EventStore schema.
- AgentEvent PR9 now instruments `CloudLLMClient.stream(...)` direct cloud
  provider calls. Streaming generation persists requested, started, and
  completed/failed AgentEvents with `cloud-llm-...` run ids,
  `cloud-llm-client` actor metadata, provider/model/mode metadata, and
  sanitized JSON payloads. Results record chunk count and output byte count
  only, never streamed text. This records the stream surface as
  `hermesGateway` class without changing provider routing, SSE parsing,
  reasoning/usage sinks, structured-output native paths, Hermes subprocesses,
  MCP, CLI, approval, UI, graph, Rust, generated bindings, or EventStore
  schema.
- AgentEvent PR10 now instruments `CloudLLMClient.generateStructured(...)`
  provider-native structured cloud generation. Structured generation persists
  requested, started, and completed/failed AgentEvents with `cloud-llm-...` run
  ids, `cloud-llm-client` actor metadata, provider/model/mode/schema metadata,
  and sanitized JSON payloads. Results record raw JSON byte/length counts only,
  never the returned structured JSON contents. This records the structured
  surface as `hermesGateway` class without changing provider routing, schema
  request construction, prompt fallback behavior, Hermes subprocesses, MCP,
  CLI, approval, UI, graph, Rust, generated bindings, or EventStore schema.
- AgentEvent PR11 now instruments `LocalAgentLoop` tool execution. Parsed local
  tool calls persist requested, started, and completed/failed AgentEvents with
  `local-agent-...` run ids, `local-agent-loop` actor metadata,
  `local-agent-tool:N` sequence ids, source/surface metadata, and bounded
  result/error payloads. This does not change model routing, tool parsing, tool
  execution, repair semantics, approvals, UI, provider calls, HookRegistry,
  PipelineService, ChatCoordinator, Omega, graph, Rust, generated bindings, or
  EventStore schema.
- AgentEvent PR12 now instruments the `DriverChannelToolExecutor` channel
  tool wrapper used by driver send/fetch/list/audit calls. Channel tool calls
  persist requested, started, and completed/failed AgentEvents with
  `driver-channel-...` run ids, `driver-channel-<channel>` actor metadata,
  `driver-channel-tool:1` ids, source/surface/channel/tier metadata, and
  bounded result/error payloads. This does not change channel adapter payload
  construction, contact routing fallback, `LocalAgentLoop`, PipelineService,
  ChatCoordinator, Omega reasoning, graph, Rust, generated bindings, approval,
  UI, provider routing, or EventStore schema.
- AgentEvent PR13 now instruments the remote relay channel HTTP client path.
  `RemoteRelayChannelAdapter` injects `URLSession` and an optional
  `AgentToolProvenanceRecorder`; send/fetch/list/audit relay requests persist
  requested, started, and completed/failed AgentEvents with
  `relay-channel-...` run ids, `relay-channel-<channel>` actor metadata,
  `relay-channel-tool:1` ids, source/surface/channel/route/method metadata,
  and sanitized JSON payloads. Message text, relay endpoint URLs,
  credentials, sender identities, relay response bodies, and HTTP error bodies
  are intentionally excluded. This does not change channel adapter parsing,
  relay request construction, native fallback semantics,
  `DriverChannelToolExecutor`, `LocalAgentLoop`, PipelineService,
  ChatCoordinator, Omega reasoning, graph, Rust, generated bindings, approval,
  UI, provider routing, or EventStore schema.
- AgentEvent PR14 now instruments `AgentGrepService.search(...)`. AgentGrep
  searches persist requested, started, and completed/failed AgentEvents with
  `agent-grep-...` run ids, `agent-grep-service` actor metadata,
  `agent-grep-search:1` tool identity, source/surface metadata, bounded kind
  filter, limit, hit count, and backend failure class. Query text, snippets,
  vault paths, file bodies, source text, sidecar provenance ids, and tool-use ids
  are intentionally excluded. This does not change search behavior, indexing,
  unindexing, sidecar enrichment, UI, approval, routing, graph, Rust, generated
  bindings, or EventStore schema.
- AgentEvent PR15 now instruments `AgentQueryEngine` backend tool streams.
  Backend `.toolUse` / `.toolResult` events persist requested, started, and
  completed/failed AgentEvents with `agent-query-engine-...` run ids,
  `agent-query-engine` actor metadata, backend/model/turn/tool metadata,
  output byte counts, and error flags. Prompt bodies, chat history, system
  prompts, cwd, backend tool inputs, backend tool outputs, raw text, thinking
  text, and session ids are intentionally excluded. This does not change backend
  streaming, prompt construction, approval, UI, provider routing,
  ChatCoordinator, PipelineService, LocalAgentLoop, LLMService, Omega, graph,
  Rust, generated bindings, or EventStore schema.
- AgentEvent PR16 now instruments `InstantRecallService.search(queryText:topK:)`
  sync recall search. Valid sync searches persist requested, started, and
  completed/failed AgentEvents with `instant-recall-...` run ids,
  `instant-recall-service` actor metadata, `instant-recall-search:N` tool ids,
  source/surface/topK/query-count metadata, hit/document counts, elapsed
  milliseconds, and bounded failure classes. Query text, note ids, note bodies,
  result text, snippets, vault paths, source text, async recall events, Halo,
  ShadowSearch, editor state, and graph state are intentionally excluded. This
  does not change recall behavior, hydration, metrics, async recall, Halo,
  ShadowSearch, UI, approval, routing, graph, Rust, generated bindings, or
  EventStore schema.
- AgentEvent PR17 now instruments `InstantRecallService.searchAsync(query:topK:)`
  async recall search. Valid async searches persist requested, started, and
  completed/failed AgentEvents with `instant-recall-async-...` run ids,
  independent `instant-recall-search-async:N` tool ids,
  `surface=instant_recall_async`, typed async failure classes, cancellation
  terminal rows, zero-hit completed rows, and FFI-only elapsed milliseconds.
  Query text, note ids, note bodies, result text, snippets, vault paths, source
  text, scores, embeddings, raw FFI JSON, Halo, ShadowSearch, editor state, and
  graph state are intentionally excluded. This does not change async recall
  behavior, hydration, MainActor metrics, UI, approval, routing, graph, Rust,
  generated bindings, or EventStore schema.
- AgentEvent PR18 now instruments `ShadowSearchService.search(text:domain:limit:)`
  backend recall search. Valid ShadowSearch calls persist requested, started,
  and completed/failed AgentEvents with `shadow-search-...` run ids,
  per-instance `shadow-search:N` tool ids, `shadow-search-service` actor
  metadata, `surface=shadow_search`, domain/limit/query-count metadata, hit
  counts, elapsed milliseconds, zero-hit completed rows, cancellation terminal
  rows, and closed ShadowFFI failure classes. Query text, hit ids, titles,
  snippets, scores, source labels, document bodies, vault paths, raw FFI payloads,
  localized descriptions, and arbitrary error text are intentionally excluded
  from persisted provenance. This does not change ShadowSearch hit behavior,
  catch-to-empty behavior, `searchOrThrow`, `stats`, Halo,
  ContextualShadowsState, UI, graph, Rust, generated bindings, or EventStore
  schema.
- AgentEvent PR19 now instruments
  `SearchIndexService.fusedSearchAsync(query:weights:now:)` on the async RRF
  fused-search rail. Valid non-empty async fused searches persist requested,
  started, and completed/failed AgentEvents with
  `search-index-fused-async-...` run ids, per-instance
  `search-index-fused-async:N` tool ids, `search-index-service` actor metadata,
  `surface=fused_search_async`, query character count, term count,
  `weights_profile=default|custom`, now timestamp, hit count, elapsed
  milliseconds, zero-hit completed rows, and closed failure classes
  `cancelled|sql_error|unknown_error`. Query text, sanitized FTS query, hit ids,
  titles, snippets, scores, source labels, document bodies, vault paths, SQL,
  GRDB error strings, localized descriptions, scalar weight values, and
  arbitrary error text are intentionally excluded from persisted provenance.
  This does not change sync `fusedSearch`, RRF SQL, VaultSyncService,
  SearchFusionMetrics semantics, UI, graph, Rust, generated bindings, or
  EventStore schema. Expanded verification passed 55 selected tests across
  `RRFFusionQueryTests`, `ReadableBlocksIndexTests`,
  `ReadableBlocksProjectorTests`, and the non-gated SearchIndex source guard;
  the existing RRF Fusion runtime suite still compiles but remains skipped on
  this host behind its FTS5 availability gate.
- AgentEvent sync recorder enabler PR0 is closed as the safe prerequisite for a
  later sync fused-search instrumentation gate. `AgentToolProvenanceRecorder`
  now shares event construction with a new nonisolated
  `AgentToolProvenanceSyncRecorder` that keeps sequence allocation behind an
  `NSLock`, preserves optional-field semantics, validates run/tool identity
  before sequence allocation, and persists via a synchronous `@Sendable`
  closure. Tests prove ordered sync lifecycle emission, EventStore schema
  compatibility, incomplete-identity refusal, absence of forbidden main-actor
  bridge patterns, and that sync `SearchIndexService.fusedSearch(...)` remains
  uninstrumented. This PR0 does not change SearchIndexService behavior, RRF SQL,
  VaultSyncService, UI, graph, Rust, generated bindings, or EventStore schema;
  PR20 closed that separate gate before any sync consumer recorded AgentEvents.
- AgentEvent PR20 now instruments
  `SearchIndexService.fusedSearch(query:weights:now:)` on the sync RRF
  fused-search rail using `AgentToolProvenanceSyncRecorder`. Valid non-empty
  sync fused searches persist requested, started, and completed/failed
  AgentEvents with `search-index-fused-sync-...` run ids, per-instance
  `search-index-fused-sync:N` tool ids, `search-index-service` actor metadata,
  `surface=fused_search`, query character count, term count,
  `weights_profile=default|custom`, now timestamp, hit count, elapsed
  milliseconds, zero-hit completed rows, and closed failure classes
  `cancelled|sql_error|unknown_error`. Query text, sanitized FTS query, hit ids,
  titles, snippets, scores, source labels, document bodies, vault paths, SQL,
  GRDB error strings, localized descriptions, scalar weight values, arbitrary
  error text, and runtime bridge details are intentionally excluded from
  persisted provenance. This does not change RRF SQL, `VaultSyncService`,
  `QueryRuntime`, SearchFusionMetrics semantics, UI, graph, Rust, generated
  bindings, or EventStore schema. Focused verification passed the non-gated
  SearchIndex source guard; the runtime RRF Fusion tests compile but remain
  skipped on this host behind the pre-existing FTS5 availability gate.
- AgentEvent PR21 now instruments direct page search for both
  `SearchIndexService.search(query:limit:)` and
  `SearchIndexService.searchAsync(query:limit:)`. Valid non-empty direct page
  searches persist requested, started, and completed/failed AgentEvents with
  `search-index-page-sync-...` / `search-index-page-async-...` run ids,
  per-instance `search-index-page-sync:N` /
  `search-index-page-async:N` tool ids, `search-index-service` actor metadata,
  `surface=search|search_async`, query character count, term count, limit, hit
  count, elapsed milliseconds, zero-hit completed rows, and closed failure
  classes `cancelled|sql_error|unknown_error`. Query text, sanitized FTS query,
  hit ids, titles, snippets, scores, source labels, document bodies, vault
  paths, SQL, GRDB error strings, localized descriptions, arbitrary error text,
  and block-search surfaces are intentionally excluded from persisted
  provenance. This does not change page-search SQL, block search, fused search,
  `VaultSyncService`, `QueryRuntime`, SearchFusionMetrics semantics, UI, graph,
  Rust, generated bindings, or EventStore schema. Focused verification passed
  the non-gated SearchIndex source guard under `pipefail`; the runtime RRF
  Fusion tests compile but remain skipped on this host behind the pre-existing
  FTS5 availability gate.
- AgentEvent PR22 now instruments SearchIndex block search for both
  `SearchIndexService.searchBlocks(query:limit:)` and
  `SearchIndexService.searchBlocksAsync(query:limit:)`. Valid non-empty block
  searches persist requested, started, and completed/failed AgentEvents with
  `search-index-block-sync-...` / `search-index-block-async-...` run ids,
  per-instance `search-index-block-sync:N` /
  `search-index-block-async:N` tool ids, `search-index-service` actor metadata,
  `surface=search_blocks|search_blocks_async`, query character count, term
  count, limit, hit count, elapsed milliseconds, zero-hit completed rows, and
  closed failure classes `cancelled|sql_error|unknown_error`. Query text,
  sanitized FTS query, block ids, page ids, titles, snippets, ranks, document
  bodies, vault paths, SQL, GRDB error strings, localized descriptions,
  arbitrary error text, and direct-page/fused surfaces are intentionally
  excluded from persisted provenance. This does not change block-search SQL,
  page search, fused search, `VaultSyncService`, `QueryRuntime`,
  SearchFusionMetrics semantics, UI, graph, Rust, generated bindings, or
  EventStore schema. Focused verification passed the non-gated SearchIndex
  source guard under `pipefail`; the runtime RRF Fusion tests compile but remain
  skipped on this host behind the pre-existing FTS5 availability gate.
- LocalAgent reflex streaming EOF flush is now closed. When reflex streaming
  ends without a detected tool call, `LocalAgentLoop` drains the detector's
  safe plaintext read-ahead buffer so trailing tag-prefix text such as a lone
  `<` is not silently dropped from note-ask/chat output. The detector still
  suppresses unclosed hidden scratchpad and malformed tool-call opens, and the
  slice does not change model routing, tool parsing, tool execution, repair
  semantics, UI, provider calls, Rust, generated bindings, or EventStore schema.
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
- Sovereign Gate Approval Surface PR3 is now closed for the existing agent tool
  approval sheet: approve-once maps to a category-scoped biometric requirement,
  `Less Interruptions` and `Always Allow` map to device-owner authentication,
  and deny/timeout remain immediate. Failed authentication resolves as deny,
  with no Rust/Omega/ChatCoordinator/generated-transport changes.
- Sovereign Gate Rust Matrix PR4 is now closed as an additive Rust-only
  classifier seed: `agent_core/src/sovereign/mod.rs` declares
  Trivial/Reversible/Sensitive/Destructive/Sovereign action classes, doctrine
  example intents, `GateRequirement`, `GateOutcome`, category-scoped Sensitive
  900-second grace, Destructive every-time device-owner auth, and a forward
  Secure-Enclave key-release requirement for Sovereign-class Pro/Research work.
  Focused Rust tests passed 6/6. This does not add generated UniFFI transport,
  Swift policy, popup migration, Secure Enclave sealing, or tool behavior
  changes.
- Sovereign Gate Notes Delete PR5 is now closed for the existing Notes Sidebar
  permanent page/folder delete confirmation surface. The existing SwiftUI
  destructive alert buttons now ask the shared `AppBootstrap` `SovereignGate`
  for `.deviceOwnerAuthentication` before delete execution, capture the pending
  target before async auth so alert dismissal cannot lose the authorized item,
  and clear pending state without deleting on denial/unavailable auth. Focused
  Swift tests passed 12/12. This does not edit `SovereignGate.swift`, duplicate
  `LocalAuthentication`, change delete planner semantics, migrate any other
  popup, or touch Rust/generated/graph/editor/Omega/ChatCoordinator surfaces.
- Sovereign Gate Chat Delete PR6 is now closed for the existing Chat Sidebar
  context-menu destructive chat delete surface. The delete action now asks the
  shared `AppBootstrap` `SovereignGate` for `.deviceOwnerAuthentication` before
  deleting the selected `SDChat`, treats missing/unavailable auth as denied, and
  preserves the existing delete implementation and error handling. Focused Swift
  tests passed 13/13. This does not edit `SovereignGate.swift`, duplicate
  `LocalAuthentication`, migrate note chat, alter chat persistence semantics, or
  touch Rust/generated/graph/editor/Omega/ChatCoordinator surfaces.
- Sovereign Gate Version Delete PR7 is now closed for the existing DiffSheet
  "Delete This Version" destructive menu surface. The menu action now routes
  through the shared `AppBootstrap` `SovereignGate` with
  `.deviceOwnerAuthentication`, captures the exact `SDPageVersion` before async
  auth so selection changes cannot redirect the delete, and preserves the
  existing delete/save/reinsert rollback semantics. Focused Swift tests passed
  15/15. This does not edit `SovereignGate.swift`, duplicate
  `LocalAuthentication`, migrate other note/editor dialogs, alter version
  persistence semantics, or touch Rust/generated/graph/Omega/ChatCoordinator
  surfaces.
- Sovereign Gate RootView Destructive PR8 is now closed for the existing
  database error "Reset Database" and vault recovery "Disconnect Vault"
  destructive controls. Both buttons now route through the shared
  `AppBootstrap` `SovereignGate` with `.deviceOwnerAuthentication` before
  calling their original closures. Red-team P2/P3 findings were addressed:
  denied reset auth restores the database recovery alert while the database
  error remains present, and vault disconnect has an in-flight auth guard to
  prevent duplicate prompts/actions. Focused Swift tests passed 17/17. This
  does not edit `SovereignGate.swift`, duplicate `LocalAuthentication`, alter
  database reset or vault recovery semantics, or touch Rust/generated/graph/
  Omega/ChatCoordinator surfaces.
- Sovereign Gate Model Vault Delete PR9 is now closed for the existing Model
  Vaults sidebar file/folder destructive delete surface. File and folder
  context-menu delete targets now carry typed `ModelVaultDeletionSovereignGate`
  targets, the alert primary action routes through the shared `AppBootstrap`
  `SovereignGate` with `.deviceOwnerAuthentication`, and delete execution only
  runs after `.allowed`. Focused Swift tests passed 19/19. This does not edit
  `SovereignGate.swift`, duplicate `LocalAuthentication`, alter model-vault
  browser/delete semantics, or touch Rust/generated/graph/Omega/ChatCoordinator
  surfaces.
- Sovereign Gate Custom Tool Delete PR10 is now closed for the existing Agent
  Control custom-tool destructive delete surface. `AgentControlSettingsView`
  now maps custom-tool delete targets through typed
  `AgentControlSettingsDeletionSovereignGate` requirements, routes the existing
  custom-tool Delete button through the shared `AppBootstrap` `SovereignGate`
  with `.deviceOwnerAuthentication`, and only calls the original
  `deleteCustomTool(named:vaultPath:)` after `.allowed`. Focused Swift tests
  passed 21/21. This does not edit `SovereignGate.swift`, duplicate
  `LocalAuthentication`, alter custom-tool manager semantics, or touch
  Rust/generated/graph/Omega/ChatCoordinator surfaces.
- Sovereign Gate Notes Vault Disconnect PR11 is now closed for the normal Notes
  Sidebar vault menu destructive disconnect surface. `VaultConnectionButton`
  now maps vault disconnect through `NotesSidebarDeletionSovereignGate`, routes
  the menu action through the shared `AppBootstrap` `SovereignGate` with
  `.deviceOwnerAuthentication`, denies safely when the gate is unavailable,
  rechecks the captured vault URL on the main actor after auth, and guards
  re-entrant taps with an in-flight flag before calling the original
  `VaultConnectionActions.disconnect(notesUI:vaultSync:)`. Focused Swift tests
  passed 23/23. This does not edit `SovereignGate.swift`, duplicate
  `LocalAuthentication`, alter vault teardown semantics, or touch
  Rust/generated/graph/Omega/ChatCoordinator surfaces.
- Sovereign Gate Authority Reset PR12 is now closed for the existing Authority
  Settings batch policy reset and Quick Setup preset surfaces.
  `AuthoritySettingsView` maps reset/default and preset targets through typed
  `AuthoritySettingsSovereignGate` requirements, routes both batch actions
  through the shared `AppBootstrap` `SovereignGate` with
  `.deviceOwnerAuthentication`, denies safely when the gate is unavailable, and
  only mutates the existing `AgentAuthorityStore` after `.allowed`. Focused
  Swift tests passed 25/25. This does not edit `SovereignGate.swift`, duplicate
  `LocalAuthentication`, alter authority persistence semantics, or touch
  Rust/generated/graph/Omega/ChatCoordinator surfaces.
- Sovereign Gate Overseer History Reset PR13 is now closed for the existing
  Overseer Settings reset-history footer. `OverseerSettingsView` maps history
  reset through typed `OverseerSettingsSovereignGate` requirements, routes the
  visible footer action through the shared `AppBootstrap` `SovereignGate` with
  `.deviceOwnerAuthentication`, denies safely when the gate is unavailable, and
  only calls `OverseerAuditState.clear()` after `.allowed`. Focused Swift tests
  passed 27/27. This does not edit `SovereignGate.swift`, duplicate
  `LocalAuthentication`, alter programmatic workspace-switch audit clearing, or
  touch Rust/generated/graph/Omega/ChatCoordinator surfaces.
- Sovereign Gate Settings Reset Everything PR14 is now closed for the existing
  General Settings "Reset Everything" alert. `SettingsView` maps the reset
  target through typed `SettingsViewDestructiveActionSovereignGate`
  requirements, preserves the existing first alert, routes the destructive
  confirmation through the shared `AppBootstrap` `SovereignGate` with
  `.deviceOwnerAuthentication`, denies safely when the gate is unavailable, and
  only calls `resetAllData()` after `.allowed`. Focused Swift tests passed
  29/29. This does not edit `SovereignGate.swift`, duplicate
  `LocalAuthentication`, alter reset semantics, stage unrelated Settings
  diagnostics edits, or touch Rust/generated/graph/Omega/ChatCoordinator
  surfaces.
- Sovereign Gate Settings Workspace Delete PR15 is now closed for the existing
  General Settings saved-workspace trash action. `SettingsView` maps saved
  workspace deletes through typed `SettingsViewDestructiveActionSovereignGate`
  requirements, routes the visible destructive button through the shared
  `AppBootstrap` `SovereignGate` with `.deviceOwnerAuthentication`, denies
  safely when the gate is unavailable, and only calls the original
  `workspaceService.deleteWorkspace(workspace)` plus `refreshWorkspaces()` after
  `.allowed`. Focused Swift tests passed 31/31. This does not edit
  `SovereignGate.swift`, duplicate `LocalAuthentication`, alter workspace
  service semantics, or touch Rust/generated/graph/Omega/ChatCoordinator
  surfaces.
- Sovereign Gate Settings Vault Disconnect PR16 is now closed for the existing
  Settings > Vault `Disconnect` button. `SettingsView` maps vault disconnect
  through typed `SettingsViewDestructiveActionSovereignGate` requirements,
  routes the visible destructive button through the shared `AppBootstrap`
  `SovereignGate` with `.deviceOwnerAuthentication`, denies safely when the
  gate is unavailable, disables duplicate clicks while auth is in flight,
  rechecks that the active vault URL still matches the captured URL after
  approval, and only then calls the original
  `VaultConnectionActions.disconnect(notesUI:vaultSync:)`. Focused Swift tests
  passed 33/33. This does not edit `SovereignGate.swift`, duplicate
  `LocalAuthentication`, alter vault disconnect semantics, or touch
  Rust/generated/graph/Omega/ChatCoordinator surfaces.
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
- Durable GraphEvent projection consumer PR4 is now closed. EventStore exposes
  bounded `graphEventProjectionSnapshot(limit:)`, composing the existing recent
  durable GraphEvent read with the deterministic read-only projection fold
  without renderer, retrieval, Halo, Theater, Rust, OpLog, mutation, repair,
  polling, or UI side effects.
- Durable GraphEvent projection visibility PR5 is now closed. Settings'
  existing `GraphEventVisibilityRow` reads the PR4 consumer once on
  appear/refresh and displays bounded event/node/edge counts without renderer,
  retrieval, Halo, Theater, Rust, OpLog, mutation, repair, polling, timer, or
  `.task` side effects.
- Durable GraphEvent audit projection PR6 is now closed.
  `GraphEventAuditProjectionService` consumes the existing
  `EventStore.graphEventProjectionSnapshot(limit:)` API and returns bounded
  event/node/edge counts, latest event id, node ids, edge ids, and generation
  time for audit consumers without renderer, retrieval, Halo, Theater, Rust,
  OpLog, mutation, repair, polling, timer, EventStore schema, generated-binding,
  or UI side effects.
- Durable GraphEvent Halo projection PR7 is now closed. `HaloController`
  refreshes a bounded read-only GraphEvent projection report through
  `GraphEventAuditProjectionService` when the Halo panel opens, and
  `ShadowPanelContent` displays the event/node/edge counts as a read-only
  ribbon. This is the first live Halo consumer of the durable projection spine,
  but it adds no timers, polling, graph renderer, retrieval, Theater, OpLog,
  Rust, generated bindings, EventStore schema, mutation, or repair behavior.
- Durable GraphEvent audit visibility PR8 is now closed. Settings'
  `GraphEventVisibilityRow` refreshes a bounded read-only
  `GraphEventAuditProjectionService` report on appear/refresh and displays
  event/node/edge/latest-event counts without `SettingsView` mount changes,
  renderer, retrieval, Halo, Theater, OpLog, Rust, generated bindings,
  EventStore schema, mutation, repair, polling, timer, or projection-worker
  behavior.
- Durable GraphEvent Trace Inspector projection PR9 is now closed.
  `TraceInspectorView` displays a compact read-only GraphEvent projection
  summary backed by `GraphEventAuditProjectionService().auditReport(limit: 100)`.
  The refresh path computes the report and trace-file snapshot in a detached
  utility task, cancels stale refreshes, and keeps
  `GraphEventAuditProjectionService` explicitly nonisolated/Sendable so the
  bounded read does not run on the main actor.
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
  `/tmp/epistemos-reasoning-loop-agent-event-pr7-green-20260502.log`,
  and
  `/tmp/epistemos-cloud-llm-agent-event-pr8-green-20260502.log`,
  and
  `/tmp/epistemos-cloud-llm-stream-agent-event-pr9-green-20260502.log`,
  and
  `/tmp/epistemos-graph-event-pr1-green-20260501-r1.log`,
  and
  `/tmp/epistemos-graph-event-visibility-pr2-final-20260501.log`,
  and
  `/tmp/epistemos-graph-event-projection-pr3-green-20260501.log`,
  and
  `/tmp/epistemos-graph-event-audit-projection-pr6-green-20260502.log`,
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
verification, read-only ReplayBundle export, incremental replay, and
production ReplayBundle visibility, and
`agent_events` is now the durable Swift source for agent/tool
provenance with the first PipelineService and ChatCoordinator Rust-stream live
emission paths closed, HookRegistry API-level lifecycle emission, read-only
Settings visibility, the first PipelineService HookRegistry production mount,
Omega ReasoningLoop internal tool-call emission, and CloudLLM non-streaming
cloud generation, direct streaming, and structured-output emission.
`graph_events` is now the durable Swift source for mutation-derived graph
provenance with a read-only projection snapshot fold. The next provenance gates
are AgentEvent coverage beyond PipelineService, ChatCoordinator, HookRegistry,
Omega ReasoningLoop, and CloudLLM generate/stream/structured paths, GraphEvent
projection into live graph, retrieval, Halo, and Theater surfaces, and deeper
audit/repair surfaces beyond the
current read-only Settings diagnostics, projection snapshot replay, chain
verification, incremental replay, ReplayBundle visibility,
AgentEvent visibility diagnostics, and
GraphEvent visibility/projection diagnostics.

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
- Swift incremental replay can extend read-only OpLog replay snapshots from tail
  entries without re-folding old rows, mutating projection state, or exporting
  private payloads through ReplayBundle JSON.
- Settings diagnostics now expose sanitized ReplayBundle visibility counts from
  `MutationOpLogReplayBundleVisibilityReport` without raw ABI, buttons, timers,
  or repair/export actions.
- Rust OpLog chain verification can validate persisted sequence/hash continuity
  and expected-tip anchoring through the Swift-owned raw ABI bridge.
- EventStore now persists typed agent/tool provenance in `agent_events` through
  `AgentProvenanceEvent` and bounded AgentEvent read APIs; PipelineService's
  local observed tool executor now emits requested, approved/denied, started,
  and completed/failed lifecycle rows, and ChatCoordinator's Rust stream
  consumers now emit the same lifecycle rows for Command Center and managed chat
  Rust agent sessions. HookRegistry lifecycle APIs now emit tool-less
  registered/fired/completed rows for existing hook calls, PipelineService's
  local tool-loop path now mounts HookRegistry, and Omega ReasoningLoop internal
  search calls now emit requested/started/completed-or-failed AgentEvents.
  CloudLLM non-streaming cloud generation also emits sanitized
  requested/started/completed-or-failed AgentEvents and marks the surface with
  Hermes `hermesGateway` route metadata without changing provider behavior.
  CloudLLM direct streaming now emits the same lifecycle shape with chunk/byte
  counts only, preserving existing provider streaming and SSE parsing behavior.
  CloudLLM structured generation, LocalAgentLoop parsed tool calls,
  DriverChannelToolExecutor wrappers, remote relay HTTP calls, AgentGrep search,
  and AgentQueryEngine backend tool streams now emit the same bounded lifecycle
  shape with surface-specific sanitized metadata and no prompt/body/output
  persistence.
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
- EventStore now exposes the direct read-only GraphEvent projection consumer
  `graphEventProjectionSnapshot(limit:)` so future consumers can request a
  bounded snapshot without hand-composing row reads and projection folding.
- Settings now exposes the read-only GraphEvent projection snapshot counts from
  that consumer, keeping projection visibility tied to the same bounded
  EventStore API rather than a second UI-owned fold.
- GraphEvent audit consumers can now read a bounded report from
  `GraphEventAuditProjectionService`, which consumes the existing EventStore
  projection snapshot and exposes event/node/edge counts plus deterministic
  node and edge ids without renderer, retrieval, Halo, Theater, Rust, OpLog, UI,
  or schema side effects.
- Settings now exposes that audit projection report in the existing
  `GraphEventVisibilityRow`, keeping audit visibility tied to the same bounded
  PR6 service and PR4 EventStore consumer instead of adding another UI-owned
  fold or Settings mount.
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
  marking it as `not_live_render_frame_rate`. R15 PR8 adds an opt-in live MLX
  token-throughput harness around `MLXInferenceService` and `LocalMLXClient`
  using the installed DeepSeek R1 7B MLX model; the gated harness is green, but
  the live sentinel run stopped at canonical insufficient-memory preflight
  (`requiredGB=12`, `availableGB=4`), so no live tok/s JSON artifact exists yet.
  R15 PR9 adds a test-only evidence ledger that names the ten closed R15 JSON
  artifacts and keeps the open PR8 tok/s, renderer FPS, and true Rust
  callback-loop artifact names out of the closed set. R15 PR10 adds the true
  Rust-to-Swift callback-loop baseline through a debug-only UniFFI export that
  loops in Rust and calls `AgentEventDelegate.on_text_delta`, producing
  `2026-05-02t00-00-00-000z-r15-true-rust-callback-loop-baseline-true_rust_callback_loop.json`
  with p50 682.9417 ns/callback, p95 712.60078 ns/callback, 50,000 emitted
  callbacks, and metadata marking `rust_loop_status=true_rust_to_swift_loop`.
  R15 PR11 adds the offscreen live renderer FPS fixture through
  `GraphEngine.render(width:height:)`, producing
  `2026-05-02t00-00-00-000z-r15-renderer-fps-baseline-renderer_fps_thermal_soak.json`
  with p50 119.65399546442954 fps, p95 119.8709496648827 fps, and metadata
  marking `thermal_soak_status=not_five_min_thermal_soak`. The ledger now names
  12 closed R15 artifacts while keeping MLX live tok/s explicitly open.
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
- V1 Halo protected editor mount PR1 is closed in code and focused tests:
  `ProseEditorRepresentable2.Coordinator2` uses a direct route to the existing
  `HaloController` when ambient recall is enabled and the per-vault Shadow
  backend is configured, hosts the glyph in the editor scroll view, and opens
  the existing trailing-edge `ShadowPanelController`. `HaloEditorBridge` remains
  scaffold/test-only and is not instantiated in production.
- Hermes Cloud Gateway architecture is now doc-locked: Pro/Research cloud
  models, MCP/web/browser tools, Docker/devcontainer work, and
  Claude/Codex/Kimi/Gemini CLI delegation use one unified gateway/control
  surface. Concrete adapters can be gated in-process Rex/provider paths or a
  Hermes subprocess adapter. Hermes is not Rex, not the graph, and not the
  deterministic substrate; structured evidence returns through typed artifacts,
  mutation envelopes, and gates.
- Hermes Gateway Directness PR1 is now code-closed at the prompt boundary:
  `HermesPromptBuilder.systemPrompt` names Hermes as the tool-call and
  external-intelligence membrane while preserving direct local answers for
  already-available substrate context. No provider, subprocess, MCP, cloud,
  graph, Rust, or generated transport path was touched. Red/green evidence:
  `/tmp/epistemos-hermes-gateway-directness-pr1-red-20260502.log` and
  `/tmp/epistemos-hermes-gateway-directness-pr1-green-20260502.log`.
- Hermes Gateway Fast Path PR2 is now code-closed at the prompt boundary:
  the same prompt names Hermes as the single fast gateway for cloud models, CLI
  delegation, MCP/web tools, and explicit external side effects while preserving
  direct deterministic substrate answers with no gateway hop when no external
  context is needed. External evidence is framed as structured artifacts and
  provenance, not graph or Rex authority. No runtime adapter, provider,
  subprocess, MCP, graph, Rust, generated transport, entitlement, or protected
  editor path was touched. Red/green evidence:
  `/tmp/epistemos-hermes-gateway-fast-path-pr2-red-20260502.log` and
  `/tmp/epistemos-hermes-gateway-fast-path-pr2-green-20260502.log`.
- Hermes Gateway Tier Boundary PR3 is now code-closed at the prompt boundary:
  the same prompt states cloud/provider/CLI/MCP/Hermes subprocess
  orchestration is Pro/Research only, while local Hermes-family prompt
  formatting may remain Core-safe only when it runs in-process over local
  context. No runtime adapter, provider, subprocess, MCP, graph, Rust,
  generated transport, entitlement, or protected editor path was touched.
  Red/green evidence:
  `/tmp/epistemos-hermes-gateway-tier-boundary-pr3-red-20260502.log` and
  `/tmp/epistemos-hermes-gateway-tier-boundary-pr3-green-20260502.log`.
- Hermes Gateway Policy PR4 is now code-closed as a pure Swift classification
  surface: `HermesGatewayPolicy` distinguishes Core-safe local in-process prompt
  formatting from Pro/Research cloud providers, CLI delegation, MCP/web tools,
  Hermes subprocesses, browser/computer-use, Docker/devcontainer work, and
  explicit external side effects. It also separates Wi-Fi/network need from
  subprocess policy, so offline CLI delegation is still Pro/Research while
  local prompt formatting stays Core-safe. `HermesPromptBuilder` now pulls the
  PR3 boundary wording from the policy. No runtime adapter, provider,
  subprocess launcher, MCP bridge, graph, Rust, generated transport,
  entitlement, project file, or protected editor path was touched. Red/green
  evidence: `/tmp/epistemos-hermes-gateway-policy-pr4-red-20260502.log` and
  `/tmp/epistemos-hermes-gateway-policy-pr4-green-20260502.log`.
- Hermes Gateway App Store Guard PR5 is now code-closed as a pure policy helper:
  `HermesGatewayPolicy.isAllowedInCoreAppStoreBuild(_:)` allows only
  no-network, no-subprocess Core surfaces that preserve the direct substrate
  path. In practice that means deterministic local substrate answers and
  in-process local prompt formatting stay Core/App Store-safe, while cloud,
  CLI, MCP/web, Hermes subprocess, browser/computer-use, Docker/devcontainer,
  and explicit external side effects remain Pro/Research. No runtime adapter,
  provider, subprocess launcher, MCP bridge, graph, Rust, generated transport,
  entitlement, project file, or protected editor path was touched. Red/green
  evidence: `/tmp/epistemos-hermes-gateway-app-store-guard-pr5-red-20260502.log`
  and `/tmp/epistemos-hermes-gateway-app-store-guard-pr5-green-20260502.log`.
- Hermes Gateway Route Policy PR6 is now code-closed as a pure policy helper:
  `HermesGatewayPolicy.route(for:)` and `usesHermesGateway(_:)` classify
  deterministic local substrate work as `directSubstrate`, local Hermes-family
  prompt formatting as `inProcessLocalPrompt`, and cloud/CLI/MCP/browser/Docker/
  external side effects as `hermesGateway`. This keeps Hermes unified for the
  outside world without adding gateway tax to already-local substrate answers.
  No runtime adapter, provider, subprocess launcher, MCP bridge, graph, Rust,
  generated transport, entitlement, project file, or protected editor path was
  touched. Red/green evidence:
  `/tmp/epistemos-hermes-gateway-route-pr6-red-20260502.log` and
  `/tmp/epistemos-hermes-gateway-route-pr6-green-20260502.log`.
- Hermes Gateway Evidence Return PR7 is now code-closed as a pure policy helper:
  `HermesGatewayPolicy.evidenceReturn(for:)` and
  `requiresStructuredEvidenceReturn(_:)` declare that direct substrate work
  returns no external evidence, in-process local prompt formatting returns local
  prompt context only, and every unified Hermes gateway route must return
  structured evidence/provenance rather than graph, Rex, or substrate authority.
  No runtime adapter, provider, subprocess launcher, MCP bridge, graph, Rust,
  generated transport, entitlement, project file, or protected editor path was
  touched. Red/green evidence:
  `/tmp/epistemos-hermes-gateway-evidence-return-pr7-red-20260502.log` and
  `/tmp/epistemos-hermes-gateway-evidence-return-pr7-green-20260502.log`.
- Hermes Provider Surface Policy PR8 is now code-closed as a pure policy helper:
  `HermesGatewayPolicy.Surface.cloudProviderSurfaces` explicitly groups the
  generic cloud-provider surface plus OpenAI, Anthropic, Google,
  OpenAI-compatible, and Codex account-backed provider surfaces. The external
  gateway surface list composes from that cloud-provider group so future
  provider additions stay single-edit and mechanically inherit Pro/Research,
  `hermesGateway`, network-required, no direct substrate path, and structured
  evidence/provenance policy. Claude red-team found two P1 composition gaps;
  both were fixed before merge. No runtime adapter, provider, subprocess
  launcher, MCP bridge, graph, Rust, generated transport, entitlement, project
  file, or protected editor path was touched. Red/green evidence:
  `/tmp/epistemos-hermes-provider-surface-pr8-red-20260502.log` and
  `/tmp/epistemos-hermes-provider-surface-pr8-green-20260502.log`.
- Core/MAS Tool Surface Policy PR1 is now code-closed as a Swift visible
  planning-surface guard: `ToolSurfacePolicy` resolves the current distribution
  to Core/App Store under `EPISTEMOS_APP_STORE`, `MAS_SANDBOX`, or a sandbox
  environment marker, then uses a conservative allow-list so Hermes/CLI/MCP/
  browser/computer-use/Docker/subprocess tools fail closed in Core visibility.
  Pro/Research distribution keeps gateway tools visible for Hermes-controlled
  operation, `think` stays hidden, route primitives such as `route_private` are
  not Core-visible, and tool names are canonicalized before policy lookup.
  Claude red-team blocked the initial deny-list shape and later the visible
  `route_private` surface; both were fixed before merge. No runtime adapter,
  provider, subprocess launcher, MCP bridge, graph, Rust, generated transport,
  entitlement, project file, or protected editor path was touched. Red/green
  evidence: `/tmp/epistemos-tool-surface-policy-core-mas-pr1-red-20260502.log`
  and `/tmp/epistemos-tool-surface-policy-core-mas-pr1-green-20260502.log`.
- Core/MAS ToolTier Execution Symbol Gate PR2 is now code-closed for the
  `ToolTierBridge` runtime executor: the bridge carries
  `ToolSurfacePolicy.Distribution` through visible catalog loading and
  `toolExecutor()`, then `executeToolCallBridged` denies Core/App Store-hidden
  tool names before `agent_core` bindings can run. Hidden gateway symbols such
  as `run_command`, `run_persistent`, browser/computer-use, Docker, and
  Hermes-subprocess names now return `Tool not found` in Core/App Store instead
  of falling through to FFI/bindings. Focused `ToolSurfacePolicyTests` prove the
  denial path and preserve allowed Core plus Pro/Research execution paths;
  `AgentCommandCenterStateTests`, `AppStoreHardeningTests`, and
  `ToolSchemaGrammarTests` remained green as guards. Focused evidence:
  `/tmp/epistemos-core-mas-tooltier-execution-pr2-green-20260503.log`,
  `/tmp/epistemos-core-mas-tooltier-execution-pr2-guard-green-20260503.log`,
  and `/tmp/epistemos-core-mas-tooltier-execution-pr2-schema-green-20260503.log`.
- Omega Tool Registry Core Planning PR1 is now code-closed as the Omega-side
  complement to Core/MAS Tool Surface Policy PR1: `OmegaToolRegistry` exposes
  distribution-aware planning schemas, planning JSON, prompt blocks, and raw
  Rust-catalog JSON visibility through `ToolSurfacePolicy`, while preserving
  Pro/Research's Rust `builtinToolsJson()` source of truth. Core/App Store
  planning surfaces hide terminal, automation, and computer-use tools; runtime
  MCP registration and dispatch remain untouched and are explicitly a follow-on
  execution-gate concern. Claude red-team found two P1s (`builtinCatalogJson`
  unfiltered, then source-of-truth swap); both were fixed before merge. Focused
  evidence: `/tmp/epistemos-omega-tool-registry-core-planning-pr1-green-final-20260502.log`.
- Omega Dispatch Core Execution Gate PR1 is now code-closed as the runtime
  complement to the Omega planning guard: `MCPBridge.dispatch(_:distribution:)`
  gates JSON-RPC `tools/list` and `tools/call` through `ToolSurfacePolicy`
  before requests reach the Rust dispatcher. Core/App Store `tools/list` hides
  terminal, automation, and computer-use tools; Core/App Store `tools/call`
  returns a JSON-RPC "Tool not found" error for `run_command`,
  `run_persistent`, `get_ui_tree`, `see`, and `click`; Core-safe `read_file`
  still forwards to Rust and returns pending. Pro/Research full-list dispatch
  falls through when no filtering is needed. Rust dispatcher registration,
  provider code, entitlements, graph, engine, and view files were not touched.
  Claude red-team found one P1 call-deny coverage gap; it was fixed before
  merge. Focused evidence:
  `/tmp/epistemos-omega-dispatch-core-execution-gate-pr1-green-r2-20260502.log`
  and `/tmp/epistemos-omega-dispatch-core-execution-gate-pr1-tool-surface-green-20260502.log`.
- Command Center Tool Surface Policy PR1 is now code-closed for the dormant
  Agent Command Center compatibility state: `AgentCommandCenterState` accepts a
  distribution, filters every loaded tool catalog at the `rebuildToolCatalog`
  fan-in through `ToolSurfacePolicy`, rebuilds toggles from the filtered tools,
  derives `mcpToolsByAgent` from that same filtered list, and hides Safari,
  Terminal, and Automation context providers in Core/App Store while preserving
  Notes/Files/vault/open-note context. Manually typed `@Terminal` does not
  resolve in Core because parsing uses the filtered provider list. No Omega,
  Rust, Engine, view, provider, entitlement, project, graph, or generated files
  were touched. Claude red-team found a real P0 around catalog filtering, then
  approved the hardened R3 patch with P0=0/P1=0. Focused evidence:
  `/tmp/epistemos-command-center-tool-surface-pr1-green-r3-20260502.log`.
- Halo V1 live domain re-query is now code-closed: the panel Notes/Chats picker
  calls `HaloController.selectDomain(_:)`, which reuses the latest meaningful
  editor query, refreshes the selected domain asynchronously, and keeps an open
  panel open under focused tests.
- Halo V1 visible panel actions PR3 is now code-closed: each result row renders
  source provenance plus visible `Open`, note-only `Edit`, and chat-only
  `Summarise` controls through the existing handler surface, with no retrieval,
  mutation, or editor hot-path changes.

Still open:

- Production visibility and mutating rollback/repair semantics beyond read-only
  projection snapshots, read-only ReplayBundle export, read-only incremental
  replay, and read-only chain verification.
- AgentEvent emission beyond PipelineService observed-tool, ChatCoordinator
  Rust-stream, HookRegistry API-level, PipelineService HookRegistry mount,
  Omega ReasoningLoop internal search, CloudLLM non-streaming generate,
  CloudLLM direct stream, CloudLLM structured generation, LocalAgentLoop
  tool execution, DriverChannelToolExecutor channel wrapper paths, remote relay
  channel HTTP client paths, AgentGrep search, AgentQueryEngine backend tool
  streams, InstantRecall sync recall search, and InstantRecall async recall
  search.
- Live GraphEvent consumer projection beyond durable mutation mapping,
  read-only Settings visibility, the read-only projection snapshot, the
  EventStore projection-consumer API, read-only Settings projection counts, and
  the read-only audit projection report plus Halo panel read-only projection
  ribbon, Trace Inspector projection summary, and QueryRuntime full-text
  projection hint, such as graph renderer or Theater surfaces.
- Sovereign Gate follow-through beyond the Core Swift executor, lifecycle
  observer, agent approval sheet migration, Rust action-class seed, Notes
  Sidebar page/folder delete migration, Chat Sidebar chat delete migration,
  DiffSheet version delete migration, RootView destructive controls, and Model
  Vaults sidebar file/folder delete migration: generated transport, additional
  existing confirmation-surface migrations, and any Pro/Research Secure Enclave
  or Sovereign-class routes.
- Deeper audit trail and repair UX beyond read-only projection diagnostics.
- Halo V1 manual runtime verification remains open. The protected editor
  mount/glyph/panel route, domain re-query path, and visible row actions are
  closed in code, but it is not product-ready until manual runtime verification
  is reopened and passes against a real vault.
- R15 remaining specialized baselines before any graph-engine/FFI optimization:
  live MLX token throughput under sufficient-memory/thermal-soak conditions.
  PR11 closes only the offscreen live renderer FPS fixture; five-minute/manual
  thermal-soak renderer readiness and any renderer optimization claim still
  need their own later runtime gate. Any production GRDB/768-dimensional KNN
  claim still needs its own later fixture gate.
- MAS/Core versus Pro capability symbol separation.
- Manual runtime verification for user-facing ship claims.

## Safe Next Build Order

Before using this order, resolve the active feature or concept through
`MASTER_RESEARCH_INDEX_2026_05_02.md` §22. This section is execution sequencing,
not the source-map authority. If the master index's §0 Honest Discoveries
contradict older wording below, verify current code/logs and update the gate
before building.

1. **R15 remaining specialized baselines.**
   Halo V1 protected editor mount PR1, domain re-query PR2, and visible panel
   actions PR3 are now closed in code and focused tests. Manual runtime
   verification for the recall UX is still open, but the next autonomous
   code-safe build lane is the remaining R15 baselines unless the user
   explicitly reopens manual app testing.
   PR2 real fixtures are closed for Swift graph payload construction, markdown
   parser FFI, and code-token parser FFI. PR3 is closed for editor-shell
   AppKit/TextKit fixture work. PR4 is closed for sqlite-vec 100k x 32d KNN.
   PR5 is closed for generated UniFFI callback-handle lowering/lifting only.
   PR6 is closed for `PowerGate.deferSnapshot` MLX thermal policy/backpressure
   decisions only. PR7 is closed for live `GraphEngine`/C FFI bridge fixture
   roundtrips only. PR8 now has an opt-in live MLX tok/s harness and a documented
   blocked sentinel run. PR10 is closed for the debug-only true Rust
   callback-loop export baseline. PR11 is closed for an offscreen
   `GraphEngine.render(width:height:)` renderer FPS fixture and explicitly not
   a five-minute/manual thermal-soak or optimization claim. Live MLX token
   throughput under sufficient-memory thermal soak remains the last code-safe
   R15 specialized baseline; renderer thermal/product readiness remains manual.
   Before modifying graph-engine, graph rendering, BoltFFI, live MLX inference,
   production KNN, or any hot path beyond those surfaces, run a new fixture gate
   that writes real JSON results and promotes `try?` recorder calls only when the
   benchmark becomes authoritative.

2. **R16 runtime/manual closure.**
   ETL worker execution is closed as PR3H. Memory-pressure dispatch pause is
   closed as PR3E, MAS bookmark enforcement is closed as PR3F, and
   model-derived badge visibility is closed as PR3G, and Sidecar Schema Mirror
   Card 2 is closed as audit-only/no-code because no Rust note-sidecar mirror
   exists. Do not claim full R16 product readiness until a separate
   runtime/manual gate verifies the user flow against a real vault and records
   logs.

3. **OpLog / GraphEvent / AgentEvent provenance hardening.**
   Lease/retry PR3A, dead-letter PR3B, worker scheduling PR3C, read-only
   visibility PR3D, replay snapshot PR4A, OpLog chain verification PR4B,
   OpLog ReplayBundle export PR5, OpLog incremental replay PR6,
   OpLog ReplayBundle production visibility PR7,
   AgentEvent persistence PR1,
   AgentEvent PipelineService live tool
   provenance PR2, AgentEvent ChatCoordinator Rust-stream PR3, AgentEvent
   HookRegistry lifecycle PR4, AgentEvent Settings visibility PR5, AgentEvent
  Pipeline HookRegistry mount PR6, AgentEvent Omega ReasoningLoop internal
  tool provenance PR7, AgentEvent CloudLLM generate provenance PR8, AgentEvent
  CloudLLM stream provenance PR9, AgentEvent CloudLLM structured provenance
  PR10, AgentEvent LocalAgentLoop tool provenance PR11, AgentEvent
  DriverChannelToolExecutor provenance PR12, AgentEvent remote relay channel
  provenance PR13, AgentEvent AgentGrep search provenance PR14, AgentEvent
  AgentQueryEngine backend-stream provenance PR15, AgentEvent InstantRecall sync
  recall provenance PR16, AgentEvent InstantRecall async recall provenance PR17,
  AgentEvent ShadowSearch backend provenance PR18, AgentEvent SearchIndex
  fused async provenance PR19, AgentEvent sync recorder enabler PR0,
  AgentEvent SearchIndex fused sync provenance PR20, AgentEvent SearchIndex
  direct page sync/async provenance PR21, AgentEvent SearchIndex block search
  sync/async provenance PR22, durable GraphEvent mutation mapping PR1, durable
  GraphEvent Settings visibility PR2, durable
  GraphEvent projection snapshot PR3, durable GraphEvent projection consumer
  PR4, durable GraphEvent Settings projection visibility PR5, durable
  GraphEvent audit projection PR6, durable GraphEvent Halo projection PR7,
  durable GraphEvent audit visibility PR8, durable GraphEvent Trace Inspector
  visibility PR9, and durable GraphEvent QueryRuntime projection hint PR10 are
  closed. Add remaining broader runtime AgentEvent coverage, live GraphEvent
  consumer projections beyond the closed read-only Settings/Halo/Trace
  Inspector/QueryRuntime consumers, or mutating repair/audit surfaces only
  after a new gate names the exact EventStore, OpLog, worker, runtime, and
  visibility files.

4. **Core/MAS release split audit and Sovereign follow-through.**
   Sovereign Gate Core PR1 is closed for the single Swift executor, Lifecycle
   PR2 is closed for app/session/sleep grace clearing, Approval Surface PR3
   is closed for the existing agent approval sheet, and Rust Matrix PR4 is
   closed for the additive Rust action-class seed only. Notes Delete PR5 is
   closed for the existing Notes Sidebar permanent page/folder delete surface,
   Chat Delete PR6 is closed for the existing Chat Sidebar context-menu
   destructive chat delete surface, Version Delete PR7 is closed for the
   existing DiffSheet version-delete menu surface, RootView Destructive PR8 is
   closed for database reset and vault disconnect, Model Vault Delete PR9 is
   closed for the existing Model Vaults sidebar file/folder delete surface, and
   Custom Tool Delete PR10 is closed for the existing Agent Control custom-tool
   delete surface. Notes Vault Disconnect PR11 is closed for the normal Notes
   Sidebar vault menu disconnect surface, Authority Reset PR12 is closed for
   batch authority reset/preset surfaces, Overseer History Reset PR13 is closed
   for reset-history, Settings Reset Everything PR14 is closed for the existing
   reset-all-data alert, and Settings Workspace Delete PR15 is closed for the
   saved-workspace trash action, and Settings Vault Disconnect PR16 is closed
   for the Settings Vault disconnect button.
   Future Sovereign slices must
   start from
   `docs/fusion/deliberation/sovereign_gate_core_pr1_deliberation_2026_05_02.md`
   and may only add generated requirement transport, lifecycle follow-up,
   Secure Enclave sealing, or additional existing confirmation migrations
   behind new exact gates. Also ensure Pro tunnels, Hermes, CLI passthrough,
   browser/computer-use, Docker, and external subprocess surfaces cannot leak
   into the Core/App Store build.
   For Pro/Research, Hermes/gateway is the cloud/tool control surface; direct
   CLIs are delegated tools behind it, not separate app architectures or graph
   authorities. Hermes Gateway Directness PR1 through Provider Surface PR8 and
   Core/MAS Tool Surface Policy PR1 is closed for prompt/policy/visibility
   invariants, and Core/MAS ToolTier Execution Symbol Gate PR2 is closed for the
   `ToolTierBridge` runtime executor gate. Future provider routing
   still requires a new exact gate.

5. **Halo runtime/manual follow-up.**
   The protected V1 editor mount/glyph/panel route and domain re-query path are
   code-closed, and visible row provenance/actions are code-closed as PR3.
   Remaining Halo work is manual runtime verification against a real vault; any
   UX beyond the visible Open/Edit/Summarise row actions needs a new exact gate.

6. **V1.5 typed artifacts and Pro tunnels.**
   Only after the Core provenance/retrieval/diagnostics substrate is stable.

## What Agents Can Start Now

Agents are good to work on narrow, gated cards only. The safest immediate cards
are:

- Card 5 Halo follow-up only for manual runtime verification or a new UX slice
  beyond visible row actions. V0 Shadow backend route PR1, V1 protected editor
  mount PR1, V1 live domain re-query PR2, and visible panel actions PR3 are
  already closed.
- Raw Thoughts / Provenance Spine Hardening, now starting after PR3B,
  AgentEvent PR7, AgentEvent PR8, AgentEvent PR9, AgentEvent PR10, AgentEvent
  PR11, AgentEvent PR12, AgentEvent PR17, AgentEvent PR18, AgentEvent PR19,
  AgentEvent PR20, AgentEvent PR21, AgentEvent PR22, GraphEvent PR1, GraphEvent visibility PR2,
  GraphEvent projection snapshot PR3, and GraphEvent Halo projection PR7 with remaining broader
  runtime AgentEvent coverage, live GraphEvent consumer projections beyond
  Halo's read-only ribbon, deeper repair/audit
  visibility, and trace/audit projection semantics.
  Background worker scheduling is closed as PR3C, basic read-only Settings
  visibility is closed as PR3D, read-only projection replay snapshots are
  closed as PR4A, read-only OpLog chain verification is closed as PR4B,
  read-only OpLog ReplayBundle export is closed as PR5, read-only OpLog
  incremental replay is closed as PR6, read-only OpLog ReplayBundle production
  visibility is closed as PR7, durable AgentEvent
  persistence is closed as PR1, PipelineService observed tool
  lifecycle emission is closed as PR2, ChatCoordinator Rust-stream lifecycle
  emission is closed as PR3, HookRegistry API-level lifecycle emission is
  closed as PR4, AgentEvent Settings visibility is closed as PR5, Pipeline
  HookRegistry mount is closed as PR6, Omega ReasoningLoop internal tool
  provenance is closed as PR7, CloudLLM non-streaming generate provenance is
  closed as PR8, CloudLLM direct stream provenance is closed as PR9, CloudLLM
  structured generation provenance is closed as PR10, LocalAgentLoop tool
  provenance is closed as PR11, DriverChannelToolExecutor channel provenance is
  closed as PR12, remote relay channel provenance is closed as PR13, AgentGrep
  search provenance is closed as PR14, AgentQueryEngine backend-stream
  provenance is closed as PR15, InstantRecall sync recall provenance is closed
  as PR16, InstantRecall async recall provenance is closed as PR17,
  ShadowSearch backend provenance is closed as PR18, SearchIndex fused async
  provenance is closed as PR19, SearchIndex fused sync provenance is closed as
  PR20, SearchIndex direct page sync/async provenance is closed as PR21,
  SearchIndex block search sync/async provenance is closed as PR22,
  durable GraphEvent mutation mapping is closed as PR1,
  read-only GraphEvent Settings visibility is closed as PR2, and read-only
  GraphEvent projection snapshots plus the EventStore read-only consumer API
  are closed as PR3/PR4. Read-only GraphEvent Settings projection visibility is
  closed as PR5, the audit projection report consumer is closed as PR6, the
  Halo panel read-only projection ribbon is closed as PR7, and Settings audit
  projection report visibility is closed as PR8.
- R15 Benchmark Harness PR2/PR3/PR4/PR5/PR6/PR7 real fixture baselines are closed
  for Swift graph payload construction, markdown parser FFI, code-token parser
  FFI, editor-shell AppKit/TextKit work, sqlite-vec 100k x 32d KNN, generated
  UniFFI callback-handle lowering/lifting, and MLX thermal policy/backpressure
  decisions, and live `GraphEngine`/C FFI bridge roundtrips. R15 PR8 is a green
  opt-in live MLX tok/s harness plus blocked-run evidence, not a tok/s baseline
  artifact. R15 PR9 is a green evidence-ledger guard for the closed/open
  artifact boundary, not a new benchmark. R15 PR10 is closed for the debug-only
  true Rust callback-loop export baseline, and R15 PR11 is closed for the
  offscreen live renderer FPS fixture only. Remaining R15 baseline work stays
  benchmark/test-only until a fixture gate explicitly names any production path.
- R16 follow-up only for runtime/manual verification, throughput/backfill, or
  sidecar-generation expansion behind a new exact gate. Memory-pressure
  dispatch pause is closed as PR3E, MAS bookmark enforcement is closed as PR3F,
  model-derived badge visibility is closed as PR3G, and ETL worker execution is
  closed as PR3H. Do not assign Card 2 sidecar mirror work unless a new gate
  first introduces an actual Rust note-sidecar mirror target.
- Sovereign Gate follow-up only for exact gated slices after Core PR1, Lifecycle
  PR2, Approval Surface PR3, Rust Matrix PR4, Notes Delete PR5, Chat Delete PR6,
  Version Delete PR7, RootView Destructive PR8, Model Vault Delete PR9, Custom
  Tool Delete PR10, Notes Vault Disconnect PR11, Authority Reset PR12, Overseer
  History Reset PR13, Settings Reset Everything PR14, and Settings Workspace
  Delete PR15: generated requirement transport, lifecycle follow-up
  beyond PR2's app/session/sleep grace clearing, additional existing
  confirmation surfaces migrated to `SovereignGate`, or Pro/Research Secure
  Enclave/Sovereign-class routes.

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

- Wired: controller, direct editor coordinator mount, search service, glyph, and
  trailing-edge panel scaffold. `HaloEditorBridge` remains scaffold/test-only.
- Reachable: flag-gated by `EPISTEMOS_AMBIENT_RECALL_V0=1` and requires a
  configured per-vault Shadow backend.
- Visible: glyph, panel route, and Notes/Chats domain refresh are code-mounted
  and covered by focused tests; rows also expose provenance plus visible
  Open/Edit/Summarise actions.
- Gap: manual runtime verification against a real vault.

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
foundation, R15 PR2/PR3/PR4/PR5/PR6/PR7 real fixture baselines, R15 PR8 live
MLX tok/s harness with blocked-run evidence, R15 PR9 evidence-ledger guard,
R15 PR10 true Rust callback-loop export baseline, R15 PR11 offscreen live
renderer FPS fixture baseline,
EventStore OpLog
lease/retry PR3A, EventStore OpLog dead-letter PR3B, EventStore OpLog worker scheduling PR3C,
EventStore OpLog read-only visibility PR3D, EventStore OpLog replay snapshot
PR4A, EventStore OpLog chain verification PR4B, EventStore OpLog ReplayBundle
export PR5, EventStore OpLog incremental replay PR6, EventStore OpLog
ReplayBundle production visibility PR7, AgentEvent durable persistence PR1, AgentEvent PipelineService live
tool provenance PR2, AgentEvent
ChatCoordinator Rust-stream PR3, AgentEvent HookRegistry lifecycle PR4,
AgentEvent Settings visibility PR5, AgentEvent Pipeline HookRegistry mount PR6,
AgentEvent Omega ReasoningLoop internal tool provenance PR7,
AgentEvent CloudLLM non-streaming generate provenance PR8,
AgentEvent CloudLLM direct stream provenance PR9,
AgentEvent CloudLLM structured generation provenance PR10,
AgentEvent LocalAgentLoop tool provenance PR11,
AgentEvent DriverChannelToolExecutor channel provenance PR12,
AgentEvent remote relay channel provenance PR13,
AgentEvent AgentGrep search provenance PR14,
AgentEvent AgentQueryEngine backend-stream provenance PR15,
AgentEvent InstantRecall sync recall provenance PR16,
AgentEvent InstantRecall async recall provenance PR17,
AgentEvent ShadowSearch backend provenance PR18,
AgentEvent SearchIndex fused async provenance PR19,
AgentEvent sync recorder enabler PR0,
AgentEvent SearchIndex fused sync provenance PR20,
AgentEvent SearchIndex direct page sync/async provenance PR21,
AgentEvent SearchIndex block search sync/async provenance PR22,
durable GraphEvent mutation mapping PR1,
durable GraphEvent Settings visibility PR2, durable GraphEvent projection snapshot PR3,
durable GraphEvent projection consumer PR4, durable GraphEvent Settings
projection visibility PR5,
durable GraphEvent audit projection PR6,
durable GraphEvent Halo projection PR7,
Sovereign Gate Core PR1, Sovereign Gate Lifecycle PR2, Sovereign Gate Approval
Surface PR3, Sovereign Gate Rust Matrix PR4, Sovereign Gate Notes Delete PR5,
Sovereign Gate Chat Delete PR6, Sovereign Gate Version Delete PR7, Sovereign
Gate RootView Destructive PR8, Sovereign Gate Model Vault Delete PR9, Sovereign
Gate Custom Tool Delete PR10, Sovereign Gate Notes Vault Disconnect PR11,
Sovereign Gate Authority Reset PR12, Sovereign Gate Overseer History Reset
PR13, Sovereign Gate Settings Reset Everything PR14, Sovereign Gate Settings
Workspace Delete PR15, Sovereign Gate Settings Vault Disconnect PR16, the Halo V0 Shadow
backend route, Halo V1 protected editor mount PR1, Halo V1 live domain re-query
PR2, Halo V1 visible panel actions PR3, Hermes Gateway Directness PR1,
Hermes Gateway Fast Path PR2, Hermes Gateway Tier Boundary PR3, Hermes Gateway
Policy PR4, Hermes Gateway App Store Guard PR5, Hermes Gateway Route Policy
PR6, Hermes Gateway Evidence Return PR7, Hermes Provider Surface Policy PR8, R16
memory-pressure dispatch pause PR3E,
and R16 MAS bookmark enforcement
PR3F, R16 model-derived badge
visibility PR3G, and R16 ETL worker execution PR3H, plus the R16 Sidecar Schema
Mirror Card 2 audit/no-op closure, are good to build on.
The next best build card is either remaining live GraphEvent consumer projection
beyond Halo's read-only ribbon,
remaining broader runtime AgentEvent coverage beyond the already closed
CloudLLM generate/stream/structured, LocalAgentLoop tool execution,
DriverChannelToolExecutor channel wrapper, remote relay channel HTTP client
paths, AgentGrep search, AgentQueryEngine backend streams, InstantRecall
sync/async recall search, ShadowSearch backend search, and SearchIndex fused
async/sync RRF search,
Sovereign Gate Rust/transport/additional-surface
follow-through, remaining
R15 specialized baselines, R16 runtime/manual closure, or Halo runtime/manual
verification, depending on whether the immediate priority is provenance
projection, security/policy gating, performance-safe graph/FFI work,
background retrieval, or real-vault recall proof.
