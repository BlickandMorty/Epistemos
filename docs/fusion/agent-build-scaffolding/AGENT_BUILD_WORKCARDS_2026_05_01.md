# Agent Build Workcards - 2026-05-01

## Purpose

This is the safe scaffolding pack for fast multi-agent implementation.

Do not scaffold broad fake APIs, empty placeholder systems, or "wire later"
stubs that encode guesses. The safe pattern is a vertical work card: each agent
gets source-of-truth docs, a narrow allowed write set, forbidden surfaces,
acceptance tests, evidence logs, and stop triggers. Codex then reviews the diff
and integrates only verified work.

## Non-Negotiable Rules

- Every work card still requires a deliberation gate before code changes unless
  the card is explicitly docs-only.
- Current code plus fresh logs win over plan text.
- No raw merge from stale worktrees.
- No staging, commit, stash, branch switch, generated artifact edit, or
  destructive git operation unless explicitly requested.
- No protected note editor, graph renderer/controller, `graph-engine/**`,
  `epistemos-shadow/**`, or `agent_core/**` edits without a card that names
  those paths and a gate approving them.
- Every feature must identify WRV: Wired, Reachable, Visible.
- Every agent must leave raw command logs under `/tmp/` and list them in its
  completion report.

## Work Card Template

```markdown
# Work Card - <slice name>

## Goal
<One-sentence vertical outcome.>

## Authority To Read First
- <repo docs>
- <implementation files>
- <tests>
- <research docs, if relevant>

## Allowed Write Set
- <exact files or narrow subsystem>

## Forbidden Write Set
- <protected files and adjacent tempting files>

## Implementation Contract
- <specific behavior>
- <no-go behavior>
- <data/schema/FFI contract>

## Tests And Logs
- <red test command if applicable>
- <focused test command>
- <full or regression command>
- <guardrail commands>
- <expected `/tmp/...log` names>

## Acceptance
- <observable pass/fail criteria>

## Stop Triggers
- <conditions that require stopping and reporting>

## Completion Report
- Files changed
- Tests run
- Raw log paths
- WRV proof
- Remaining risks
- Rollback
```

## Card 1 - R16 Bootstrapper ETL Dispatch And Pause UI

Goal:
Wire the existing Shadow bootstrap lifecycle to the ETL queue after the
BM25/HNSW pass, and surface honest running/paused state in the existing
Background Indexing diagnostics.

Status on 2026-05-01:
PR3D closes ShadowVaultBootstrapper ETL dispatch, ETL queue stats visibility,
and low-power/thermal/battery pause diagnostics. PR3E closes memory-pressure
dispatch pause by wiring the existing `RuntimeIssueMonitor`
`DispatchSourceMemoryPressure` observer into canonical `PowerGate` snapshots.
PR3F closes MAS/security-scoped bookmark enforcement for vault restore,
bookmark fallback, and sandbox-required watch starts. Do not assign agents to
rebuild PR3D, PR3E, or PR3F. PR3G closes model-derived sidecar badge
visibility in the note workspace footer without touching the protected
ProseEditor bridge. PR3H closes honest ETL worker execution: queued jobs reach
`done` only after Rust validates file existence, readability, byte length,
input kind, and fingerprint. Remaining R16 work is runtime/manual verification
or a separately gated throughput/backfill/productization slice.

Authority to read first:
- `docs/fusion/deliberation/r16_etl_pr3_background_indexing_status_shell_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/r16_etl_apalis_queue_pr2_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/r16_etl_stats_swift_diagnostics_pr3b2_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/r16_afm_sidecar_generation_pr3c_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/r16_memory_pressure_pause_pr3e_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/r16_mas_bookmark_enforcement_pr3f_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/r16_model_derived_badge_pr3g_deliberation_2026_05_01.md`
- `docs/plan/03_EXECUTION_MAP.md` R16 section
- `Epistemos/Engine/ShadowVaultBootstrapper.swift`
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/Views/Settings/EditorBundleHealthRow.swift`
- `Epistemos/State/PowerGate.swift`
- `Epistemos/State/ThermalGuard.swift`
- `EpistemosTests/ShadowVaultBootstrapperTests.swift`

Allowed write set:
- `Epistemos/Engine/ShadowVaultBootstrapper.swift`
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/Views/Settings/EditorBundleHealthRow.swift`
- `EpistemosTests/ShadowVaultBootstrapperTests.swift`
- A new Swift ETL dispatch client only if the gate names its exact file.
- Docs under `docs/fusion/**`

Forbidden write set:
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- `epistemos-shadow/**`
- `agent_core/**` unless the gate explicitly includes a Rust dispatch API
- Xcode project files, entitlements, generated bindings, generated libraries,
  DerivedData, `.xcresult`, staging, commits, stashes, or branch operations

Implementation contract:
- Use the existing ETL queue/stats foundation rather than inventing a second
  queue.
- Do not create an ETL database merely to display diagnostics.
- Use `PowerGate.deferSnapshot()` / `PowerGate.shouldDefer()` for pause
  decisions. Memory-pressure pause is already part of that canonical path.
- Display "Paused - on battery" or equivalent honest copy when the pause path
  is reachable.
- Keep AFM generation failures nonfatal to indexing.

Tests and logs:
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ShadowVaultBootstrapperTests test`
- `cargo test --manifest-path agent_core/Cargo.toml etl --lib` if Rust ETL is
  touched or dispatch behavior depends on current ETL tests.
- `git diff --check -- <allowed files> docs/fusion`
- Protected-path name-only diff scan.
- Logs must use `/tmp/epistemos-r16-pr3d-...-20260501.log` names.

Acceptance:
- A real bootstrap path can enqueue ETL work after Shadow indexing, or the card
  must explicitly remain diagnostics-only and say so in visible copy.
- Diagnostics show running/paused/stopped plus file counts from the canonical
  state source.
- Full R16 product readiness is not claimed until a separate runtime/manual gate
  verifies the user flow against a real vault. MAS bookmark enforcement is
  already closed as PR3F, sidecar badge visibility is closed as PR3G, and ETL
  worker execution is closed as PR3H.

Stop triggers:
- The implementation needs new Rust FFI not approved by the PR3D gate.
- It needs protected editor or graph files.
- It bypasses security-scoped vault boundaries.
- It marks sidecars generated without using `EpistemosSidecarStore`.

## Card 2 - R16 Sidecar Schema Mirror Gate

Status on 2026-05-02:
Closed as a docs-only audit/no-op for code. The May 2 refresh found no active
Rust reader or writer for note `<stem>.epistemos.json` sidecars, so the Card 2
stop trigger applies: do not invent a Rust mirror in this card. Swift remains
the active source of truth through `EpistemosSidecarStore` and AFM writes
optional generated payload fields through that store. Future Rust mirror work
requires a separate gate naming exact Rust files plus parity fixtures for v2/v3
payloads and additive fields.

Goal:
Ensure any Rust-side sidecar reader/writer accepts the current Swift sidecar
contract, including generated payload fields.

Authority to read first:
- `Epistemos/Engine/EpistemosSidecar.swift`
- `Epistemos/Engine/AFMSidecarGenerator.swift`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_033_2026_05_01.md`
- `docs/fusion/deliberation/w1012_sidecar_interpretation_directive_deliberation_2026_04_30.md`
- `docs/fusion/deliberation/r16_afm_sidecar_generation_pr3c_deliberation_2026_05_01.md`
- `rg -n "EpistemosSidecar|epistemos.json|suggested_links|modelDerived" agent_core epistemos-shadow graph-engine Epistemos`

Allowed write set:
- Docs-only by default.
- Rust sidecar mirror files only after a separate gate names exact files.
- Swift sidecar tests only if the gate names exact tests.

Forbidden write set:
- Any schema version bump without compatibility tests.
- Any generated binding edit without a binding-specific gate.
- Any change that makes legacy v2/v3 sidecars fail to decode.

Implementation contract:
- Optional fields must remain optional unless a migration plan is approved.
- Rust must not reject sidecars containing `summary`, `tags`, `entities`,
  `suggested_links`, `child_concept`, or `interpretation_directive`.
- Source-code sidecar exclusion remains intact.

Tests and logs:
- Swift sidecar focused tests.
- Rust JSON decode tests if a Rust mirror exists.
- `rg` audit proving no strict stale decoder remains.
- Closed-audit evidence:
  `/tmp/epistemos-r16-sidecar-schema-rust-mirror-audit-20260502.log`,
  `/tmp/epistemos-r16-sidecar-schema-swift-surfaces-20260502.log`,
  `/tmp/epistemos-r16-sidecar-schema-strict-decoder-audit-20260502.log`, and
  `/tmp/epistemos-r16-sidecar-schema-swift-green-20260502.log`.

Acceptance:
- The sidecar contract is documented and tested on every active read/write
  surface.
- Closed result: Swift active surfaces are documented/tested; Rust has no active
  note-sidecar surface to test or patch in this card.

Stop triggers:
- No actual Rust sidecar mirror exists. In that case write an audit note only;
  do not invent one inside this card.
- A migration is required. Open a separate migration gate.

## Card 3 - R15 Benchmark Harness Foundation

Status update 2026-05-02:
PR1 JSON recorder foundation is closed. PR2 real fixture baselines are also
closed for Swift graph payload construction, markdown parser FFI, and
code-token parser FFI. PR3 editor-shell AppKit/TextKit fixture baseline is
closed. PR4 sqlite-vec 100k x 32d KNN fixture baseline is closed. The existing
disabled manual benchmark suites now write validated machine-readable JSON
through `BenchmarkRunRecorder`, and the recorder contract is tested. PR5 closes
the generated UniFFI callback-handle baseline and explicitly does not claim the
future true Rust-to-Swift callback-loop export. PR6 closes the MLX thermal
policy/backpressure baseline over `PowerGate.deferSnapshot` and explicitly does
not claim live MLX inference token throughput. PR7 closes the live
`GraphEngine`/C FFI bridge fixture baseline and explicitly does not claim live
renderer FPS or graph optimization. PR8 adds an opt-in live MLX token
throughput harness that reaches `MLXInferenceService` and `LocalMLXClient`
against the installed DeepSeek R1 7B MLX model, but the live sentinel run was
blocked by canonical memory preflight (`requiredGB=12`, `availableGB=4`), so it
does not claim tok/s yet. Remaining specialized baselines for live MLX token
throughput under sufficient-memory/thermal-soak conditions and the true Rust
callback-loop export stay open for later fixture gates; production GRDB/768d KNN
still needs its own future gate before any product claim.

Goal:
Create measurement scaffolding before touching graph renderer, FFI, or
performance-sensitive storage.

Authority to read first:
- `docs/plan/03_EXECUTION_MAP.md` R15 section
- `docs/architecture/BOLTFFI_AUDIT_2026_04_15.md`
- `docs/fusion/FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md` benchmark harness item
- Existing benchmark files under `bench/`
- Existing performance tests under `EpistemosTests/*Performance*`

Allowed write set:
- Benchmark/test-only files named by the deliberation gate.
- Docs under `docs/fusion/**`

Forbidden write set:
- `graph-engine/src/renderer.rs`
- graph physics internals
- `Epistemos/Views/Graph/MetalGraphView.swift`
- production FFI replacement code
- generated artifacts

Implementation contract:
- Measure before optimizing.
- Keep benchmark harness out of shipping hot paths.
- Emit machine-readable results under a non-shipping results path.

Tests and logs:
- Focused benchmark compile/run command chosen by the gate.
- Guardrail diff check.
- Protected-path scan proving production graph internals were not touched.

Acceptance:
- A future graph/FFI optimization card can cite a repeatable baseline.
- For PR2-closed surfaces, cite the deterministic JSON reports under
  `benchmarks/results/`:
  `graph_payload_construction_750_nodes`,
  `markdown_parser_160_sections`, and `code_token_parser_1200_lines`.
- For PR3/PR4-closed surfaces, cite the editor-shell fixture JSON reports and
  `2026-05-01t00-00-00-000z-r15-sqlite-vec-knn-sqlite_vec_knn_100k_32d.json`.
- For PR5-closed surfaces, cite
  `2026-05-02t00-00-00-000z-r15-uniffi-callback-baseline-uniffi_callback_handle_roundtrip_10000.json`
  as a generated UniFFI callback-handle baseline only.
- For PR6-closed surfaces, cite
  `2026-05-02t00-00-00-000z-r15-mlx-thermal-policy-baseline-mlx_thermal_policy_snapshot_1000.json`
  as an MLX thermal policy/backpressure baseline only, not live MLX tok/s.
- For PR7-closed surfaces, cite
  `2026-05-02t00-00-00-000z-r15-graph-ffi-bridge-baseline-graph_ffi_bridge_fixture_250.json`
  as a live `GraphEngine`/C FFI bridge fixture baseline only, not live renderer
  FPS or graph optimization.
- For PR8, cite
  `docs/fusion/deliberation/r15_mlx_live_token_throughput_pr8_deliberation_2026_05_02.md`
  as the opt-in live MLX tok/s harness and blocked-run evidence only. There is
  no PR8 tok/s JSON artifact yet because the live sentinel run stopped at
  canonical insufficient-memory preflight.
- For remaining specialized surfaces, the baseline must come from a later real
  fixture gate, not the PR1 placeholder bodies.

Stop triggers:
- The harness requires production renderer edits.
- Results are not repeatable or are not written to logs.

## Card 4 - Quick Capture Typed Artifact Vertical Slice

Status on 2026-05-01:
Closed as already-current for the minimal typed-artifact vertical slice. See
`docs/fusion/deliberation/quick_capture_typed_artifact_current_state_deliberation_2026_05_01.md`
and
`docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`.

Do not assign agents to rebuild this scaffold. Future Quick Capture donor ideas
such as universal undo, route capture, review/defer, semantic cache, and heal
loops require new gates.

Goal:
Make one minimal Quick Capture path persist through the typed artifact and
provenance spine rather than loose markdown-only state.

Authority to read first:
- `docs/fusion/FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md` Quick Capture item
- `docs/fusion/CANONICAL_SOURCE_MAP_AND_GATE_REGISTER_2026_04_30.md` Quick
  Capture source cluster
- Current Quick Capture UI and App Intent files found by
  `rg -n "QuickCapture|CaptureBrainDumpIntent|RawThought|MutationEnvelope" Epistemos EpistemosTests`
- `Epistemos/Models/MutationEnvelope.swift`
- Relevant donor worktree inventory before copying any idea

Allowed write set:
- Exact Quick Capture UI/intent/model/test files named by the gate.
- Docs under `docs/fusion/**`

Forbidden write set:
- Raw worktree merge.
- Pro-only browser/computer-use tools.
- Protected note editor internals.
- Broad `agent_core` registry rewrites.

Implementation contract:
- Preserve verbatim user input.
- Emit or link a typed provenance artifact before claiming UI success.
- Keep Core/MAS path free of shell, Docker, or external CLI spawning.

Tests and logs:
- A failing test first for the selected capture path.
- Focused Swift Testing suite for capture/provenance.
- Source audit for subprocess/pro-only leakage.

Acceptance:
- One real capture gesture is Wired, Reachable, Visible.
- The output can answer what created it and where it was stored.

Stop triggers:
- The implementation bypasses `MutationEnvelope` or equivalent provenance.
- It depends on donor worktree code without revalidating current APIs.

## Card 5 - Halo Live Loop Proof

Status update 2026-05-02:
PR1 V0 Shadow backend route is closed. The production-mounted Contextual
Shadows V0 surface now prefers `ShadowSearchService` when AppBootstrap has a
current per-vault Shadow backend, preserves `InstantRecallService` fallback,
shows source provenance, and guards vault switches against stale backend or
page-reindex writes. PR1 V1 protected editor mount is closed behind
`docs/fusion/deliberation/halo_v1_editor_mount_pr1_deliberation_2026_05_02.md`:
`ProseEditorRepresentable2.Coordinator2` installs the Halo only when ambient
recall is enabled and a Shadow backend is configured, feeds `HaloController`
through the existing `textDidChange` path, hosts the glyph in the editor
scroll view, and opens `ShadowPanelController` anchored to the editor rect.
Production still does not instantiate `HaloEditorBridge`, because that bridge
claims `NSTextView.delegate` and is scaffold/test-only for this route. PR2 live
domain re-query is closed behind
`docs/fusion/deliberation/halo_v1_domain_requery_pr2_deliberation_2026_05_02.md`:
`ShadowPanelContent` now routes the Notes/Chats segmented picker to
`HaloController.selectDomain(_:)`, and the controller reuses the latest
meaningful editor query so an open panel stays open while refreshing results
for the selected domain. PR3 visible panel actions is closed behind
`docs/fusion/deliberation/halo_v1_visible_panel_actions_pr3_deliberation_2026_05_02.md`:
result rows now render source provenance inline plus visible `Open`, note-only
`Edit`, and chat-only `Summarise` actions through the existing handler surface,
with no retrieval, mutation, or editor hot-path changes.

Goal:
Prove the minimal Halo/Contextual Shadows recall loop is wired to real current
context and visible without editor hot-path regressions.

Authority to read first:
- `docs/fusion/FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md` Halo item
- `docs/fusion/deliberation/halo_contextual_shadows_audit_defer_deliberation_2026_04_30.md`
- `Epistemos/Engine/HaloController.swift`
- `Epistemos/Engine/HaloEditorBridge.swift`
- `Epistemos/Engine/ShadowSearchService.swift`
- `Epistemos/Views/Recall/ContextualShadowsPanel.swift`
- `EpistemosTests/HaloControllerTests.swift`
- `EpistemosTests/HaloEditorBridgeTests.swift`
- `EpistemosTests/ContextualShadowsStateTests.swift`

Allowed write set:
- Halo/search/panel files named by the gate.
- Tests named by the gate.
- Docs under `docs/fusion/**`
- Protected editor files named by a dedicated gate. PR2 used
  `ProseEditorRepresentable2.swift` only.

Forbidden write set:
- `Epistemos/Views/Notes/ProseEditor*.swift` without a protected editor gate.
- `graph-engine/**`
- `MetalGraphView.swift`
- `HologramController.swift`

Implementation contract:
- No per-keystroke disk/body load cascade.
- No main-thread heavy retrieval.
- Cards must show provenance and source.
- If editor integration is required, stop and open a protected-path gate.

Tests and logs:
- Focused Halo/controller/editor-bridge tests.
- Manual app verification only when the user reopens manual runtime testing.
- Source audit for hot-path `loadBody()` and unbounded timers.
- PR3 red/green logs:
  `/tmp/epistemos-halo-v1-visible-actions-pr3-red-20260502.log` and
  `/tmp/epistemos-halo-v1-visible-actions-pr3-green-20260502.log`.

Acceptance:
- Wired: production caller exists.
- Reachable: documented user gesture reaches it.
- Visible: panel/card/log proves the recall happened.
- PR1 satisfied this for the V0 Shadow backend route. PR2 satisfies the
  protected V1 editor mount in code and focused tests. PR2 live domain re-query
  is also closed in code and focused tests. PR3 visible row provenance/actions
  is closed in code and focused tests. Future Halo work should target manual
  runtime verification or a newly gated UX slice beyond the now-visible
  Open/Edit/Summarise row actions.

Stop triggers:
- Protected editor edit needed.
- Recall results have no provenance.
- Typing latency or SwiftUI cascade risk appears.

## Card 6 - EventStore To OpLog Projection Gate

Status on 2026-05-01:
Closed as the PR2 foundation slice, PR3A lease/retry foundation, and PR3B
dead-letter foundation. PR3C also closes the smallest production scheduling
worker shell. PR3D closes basic read-only Settings visibility for projection
health and dead letters. PR4A closes Swift-only read-only projection replay
snapshots and logical cutoff rollback inspection. PR4B closes read-only
cryptographic OpLog chain verification and expected-tip anchoring. See:

- `docs/fusion/deliberation/eventstore_oplog_projection_pr2_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/eventstore_oplog_projection_lease_retry_pr3a_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/eventstore_oplog_projection_dead_letter_pr3b_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/eventstore_oplog_projection_worker_pr3c_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/eventstore_oplog_projection_visibility_pr3d_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/eventstore_oplog_replay_snapshot_pr4a_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/oplog_chain_verification_pr4b_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_038_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_041_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_042_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_044_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_045_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`

Do not assign agents to rebuild the basic projection scaffold. Future
provenance work should open new gates for incremental replay, ReplayBundle
export, live AgentEvent emission, GraphEvent projection, or deeper audit/repair
surfaces. Background projection worker scheduling is already closed as PR3C.
Basic read-only dead-letter/projection visibility is already closed as PR3D.
Read-only projection replay snapshots are already closed as PR4A. Read-only
cryptographic chain verification is already closed as PR4B.

Goal:
Mirror committed `MutationEnvelope` provenance into the append-only Rust OpLog
without creating a second source of truth or production UI dependency.

Authority to read first:
- `docs/fusion/deliberation/oplog_swift_bridge_pr1_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_037_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `Epistemos/State/EventStore.swift`
- `Epistemos/Models/MutationEnvelope.swift`
- `Epistemos/Engine/RustOpLogFFIClient.swift`
- `agent_core/src/oplog.rs`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `EpistemosTests/MutationEnvelopeParityTests.swift`

Allowed write set:
- `Epistemos/State/EventStore.swift`
- `Epistemos/Engine/RustOpLogFFIClient.swift`
- A new narrow projection service file only if the deliberation gate names it.
- `EpistemosTests/CognitiveSubstrateTests.swift`
- Focused EventStore/projection tests named by the gate.
- `agent_core/src/oplog.rs` only for narrowly required payload/ABI support named
  by the gate.
- Docs under `docs/fusion/**`

Forbidden write set:
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- `epistemos-shadow/**`
- generated bindings, generated libraries, Xcode project files, entitlements,
  DerivedData, `.xcresult`, staging, commits, stashes, or branch operations

Implementation contract:
- EventStore remains the source of committed `MutationEnvelope` persistence.
- OpLog projection must be append-only and idempotent across restart/retry.
- Projection must preserve trace id, artifact id, operation, actor/tool/model
  provenance, and committed timestamp if those fields are available.
- No UI success path may depend on OpLog until the projection has focused tests.
- No background worker may spin or allocate per-frame/per-keystroke.
- PR3A already supplies deterministic claim/retry primitives: owner-scoped
  leases, retry deadlines, attempt counts, bounded last errors, and
  owner-guarded projection marking. Do not reimplement these in a new worker
  gate; call the existing EventStore APIs.
- PR3B already supplies max-attempt dead-letter primitives: dead-letter
  timestamp/reason metadata, claim/pending exclusion, bounded last-error
  visibility, and explicit projection repair clearing. Do not reimplement these
  in a new worker gate; call the existing EventStore APIs.
- PR3C already supplies the finite production scheduling shell:
  `MutationOpLogProjectionWorker` is scheduled once from AppBootstrap deferred
  runtime services, lazily creates `RustOpLogFFIClient`, coalesces drains, and
  delegates projection semantics to `MutationOpLogProjector`. Do not add a
  timer, loop, second scheduler, or duplicate projector.
- PR3D already supplies read-only Settings visibility through EventStore
  diagnostics. Do not add raw OpLog ABI calls, polling loops, repair buttons, or
  duplicate projection diagnostics in a future provenance gate.
- PR4A already supplies read-only projection replay snapshots over decoded
  `OpLogEntry` values. Do not rebuild this fold layer; future replay work should
  target incremental replay, ReplayBundle export, or production visibility
  behind a new gate.
- PR4B already supplies read-only cryptographic chain verification and
  expected-tip anchoring over the Rust OpLog through `RustOpLogFFIClient`. Do
  not add repair, rollback execution, Settings buttons, generated bindings, or
  a second raw ABI bridge in future verification gates.
- If new Rust payload variants are needed, add serde parity tests before Swift
  wiring.

Tests and logs:
- Red test first for the selected projection behavior.
- `cargo test --manifest-path agent_core/Cargo.toml oplog --lib` if Rust payload
  or ABI is touched.
- Focused Swift tests for EventStore projection/retry/idempotency. PR3A green
  evidence is `/tmp/epistemos-oplog-lease-retry-pr3a-green-20260501.log`.
- PR3B dead-letter green evidence is
  `/tmp/epistemos-oplog-dead-letter-pr3b-green-2-20260501.log`.
- PR3C worker green evidence is
  `/tmp/epistemos-oplog-worker-pr3c-green-20260501.log`.
- PR3C boundary evidence is
  `/tmp/epistemos-oplog-worker-pr3c-boundary-20260501.log`.
- PR3D visibility evidence is
  `/tmp/epistemos-oplog-visibility-pr3d-focused-2-20260501.log`.
- PR4A replay snapshot evidence is
  `/tmp/epistemos-oplog-replay-pr4a-green-20260501.log`.
- PR4B chain verification evidence is
  `/tmp/epistemos-oplog-chain-verify-pr4b-green-cargo-20260501-r1.log` and
  `/tmp/epistemos-oplog-chain-verify-pr4b-green-xcode-20260501-r1.log`.
- Existing OpLog bridge/boundary tests.
- `git diff --check -- <allowed files> docs/fusion`
- Production raw-symbol grep excluding `RustOpLogFFIClient`.
- Protected-path name-only diff scan.
- Logs must use `/tmp/epistemos-eventstore-oplog-projection-...-20260501.log`.

Acceptance:
- Wired: a committed envelope can be projected into OpLog through the approved
  production-safe path.
- Reachable: the projection is reachable from existing EventStore/outbox flow or
  an explicitly named test-only projection entrypoint for this slice.
- Visible: tests can show the OpLog row, sequence, chain-tip advancement, and
  restart-safe idempotency.
- Visible diagnostics: Settings can show projection/dead-letter health through
  EventStore without mutating rows.
- Replay snapshot: decoded OpLog projection entries can produce deterministic
  read-only snapshots and cutoff rollback views without mutating rows.
- Chain verification: persisted OpLog rows can be checked for sequence/hash
  continuity and optional expected-tip anchoring without mutating rows.

Stop triggers:
- Projection requires protected editor or graph files.
- Projection bypasses `EventStore.saveMutationEnvelope`.
- Retry/idempotency cannot be proven.
- The implementation needs broad `agent_core` registry rewrites or generated
  binding edits.
- The slice starts adding UI, AgentEvent, or GraphEvent features instead of
  closing the projection contract.

## Card 7 - AgentEvent Tool Provenance

Status on 2026-05-01:
PR1 durable EventStore persistence is closed. Swift now has
`AgentProvenanceEvent`, typed tool provenance payloads, an `agent_events` table
with unique `event_id`, and bounded EventStore APIs:
`saveAgentEvent(_:)`, `loadAgentEvent(eventID:)`, and
`agentEvents(runID:limit:)`.

PR2 PipelineService live tool provenance is also closed. The local
`PipelineService.observedToolExecutor(...)` chokepoint now persists requested,
approved/denied, started, and completed/failed lifecycle rows for observed
local tool execution without changing approval, execution, UI, streaming, or
routing semantics. Do not assign another agent to rebuild this same
PipelineService instrumentation.

PR3 ChatCoordinator Rust-stream provenance is also closed. Both
`AgentStreamEvent` consumers in `ChatCoordinator` now persist requested,
approved/denied, started, and completed/failed lifecycle rows for Command
Center and managed chat Rust agent sessions without changing approval,
execution, UI, streaming, routing, Rust bindings, OpLog, GraphEvent, Omega,
hooks, or generated files. Do not assign another agent to rebuild this same
ChatCoordinator Rust-stream instrumentation.

PR4 HookRegistry lifecycle provenance is also closed at the API level.
Registering and firing existing hooks now persists tool-less `hook_registered`,
`hook_fired`, and `hook_completed` rows with source, hook id, hook point, run id,
sequence, and completion outcome metadata while preserving hook order and
cancellation semantics. Do not assign another agent to rebuild HookRegistry
instrumentation. Production hook call-site mounting still requires a separate
runtime gate.

PR5 read-only Settings visibility is also closed. EventStore exposes bounded
`agentEventDiagnostics()` for total rows, distinct runs, distinct tools, latest
event metadata, and last kind, and Settings mounts `AgentEventVisibilityRow`
as a diagnostic-only surface. Do not assign another agent to rebuild this
same AgentEvent visibility row.

The durable model is intentionally named `AgentProvenanceEvent` because
generated UniFFI Swift already contains an unrelated `AgentEvent` struct. Do
not rename it back without a generated-binding gate.

Goal:
Persist and then wire bounded agent/tool provenance so future agent work can
answer who requested a tool, what was approved, what ran, what failed, and
which run/trace it belongs to.

Authority to read first:
- `docs/fusion/deliberation/agent_event_tool_provenance_pr1_deliberation_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `/tmp/epistemos-agent-event-pr1-green-20260501.log`
- `Epistemos/Models/AgentProvenanceEvent.swift`
- `Epistemos/State/EventStore.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `Epistemos/App/ChatCoordinator.swift` only for PR3 evidence or a future
  regression fix gate.
- `Epistemos/Engine/HookRegistry.swift` only for PR4 evidence or a future
  production hook call-site mounting gate.

Allowed write set:
- PR1 persistence-only: already closed.
- PR2 PipelineService observed tool instrumentation: already closed.
- PR3 ChatCoordinator/Rust-stream instrumentation: already closed.
- PR4 HookRegistry API-level lifecycle instrumentation: already closed.
- PR5 read-only Settings visibility: already closed.
- Future Omega, production hook call-site, or broader runtime
  instrumentation only after a new deliberation gate names exact runtime files
  and focused tests.
- Docs under `docs/fusion/**`.

Forbidden write set:
- Production chat, Omega, hooks, approvals, or tool execution without a fresh
  live-emission gate.
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- `agent_core/**`
- generated Swift/header bindings, generated libraries, Xcode project files,
  entitlements, DerivedData, `.xcresult`, staging, commits, stashes, or branch
  operations.

Implementation contract:
- EventStore remains the durable Swift source for `agent_events`.
- Preserve lower-snake-case JSON and bounded reads.
- Failed and denied tool events are first-class events, not exceptions from the
  EventStore persistence API.
- Future live emission must be additive instrumentation only: no approval,
  routing, tool execution, or UI control-flow changes unless explicitly gated.
- Do not project AgentEvents into OpLog, GraphEvent, Halo, Theater, or
  ReplayBundle until a separate projection gate exists.

Tests and logs:
- PR1 red log: `/tmp/epistemos-agent-event-pr1-red-20260501.log`.
- PR1 green log: `/tmp/epistemos-agent-event-pr1-green-20260501.log`.
- PR2 red log: `/tmp/epistemos-agent-event-pr2-red-20260501.log`.
- PR2 Kimi advisory:
  `/tmp/epistemos-agent-event-pr2-kimi-advisory-20260501.log`.
- PR2 final green log:
  `/tmp/epistemos-agent-event-pr2-combined-green-20260501-r3.log`.
- PR3 red log: `/tmp/epistemos-agent-event-pr3-red-20260501-r2.log`.
- PR3 green log: `/tmp/epistemos-agent-event-pr3-green-20260501-r1.log`.
- PR3 Kimi audit attempt:
  `/tmp/epistemos-agent-event-pr3-kimi-audit-20260501-r1.log` produced no
  output after several minutes and was terminated.
- PR4 red log:
  `/tmp/epistemos-agent-event-hook-pr4-red-20260501.log`.
- PR4 EventStore green log:
  `/tmp/epistemos-agent-event-hook-pr4-green-eventstore-20260501.log`.
- PR4 runtime source-guard green log:
  `/tmp/epistemos-agent-event-hook-pr4-green-runtime-20260501.log`.
- PR5 red log:
  `/tmp/epistemos-agent-event-visibility-pr5-red-20260502.log`.
- PR5 green log:
  `/tmp/epistemos-agent-event-visibility-pr5-green-20260502.log`.
- PR5 EventStore regression green log:
  `/tmp/epistemos-agent-event-visibility-pr5-eventstore-regression-20260502.log`.
- Future live-emission PRs must write a failing test first for the selected
  path, then a focused green Swift Testing log.
- Guardrails: `git diff --check`, source grep for forbidden production paths,
  and protected-path name-only diff scan.

Acceptance:
- PR1 wired: durable typed model plus EventStore table/API.
- PR1 reachable: focused tests save, load, list, and idempotently update
  AgentEvent provenance rows.
- PR1 visible: tests prove lower-snake-case JSON, bounded ordering, and table
  creation.
- PR2 wired/reachable/visible: PipelineService observed local tools emit
  requested, approved/denied, started, and completed/failed rows with non-empty
  run id and tool call id. Trace id remains nil in PR2 because that chokepoint
  does not expose a canonical trace id.
- PR3 wired/reachable/visible: ChatCoordinator Command Center and managed chat
  Rust stream loops emit typed events for exposed permission and tool lifecycle
  events without changing behavior. Trace id remains nil because these paths do
  not expose a canonical trace id today.
- PR4 wired/reachable/visible: HookRegistry lifecycle APIs emit typed,
  tool-less registered/fired/completed rows for existing hook invocations,
  preserve cancellation behavior, and are source-guarded away from
  PipelineService, ChatCoordinator, Omega, OpLog, GraphEvent, editor, graph,
  Rust, and generated bindings.
- PR5 wired/reachable/visible: EventStore returns bounded read-only AgentEvent
  diagnostics, and Settings mounts `AgentEventVisibilityRow` beside the sibling
  provenance diagnostics without schema, emission, routing, OpLog, GraphEvent,
  editor, graph, Rust, or generated-binding changes.

Stop triggers:
- A live-emission slice needs broad `agent_core`, generated binding, editor,
  graph, or UI rewrites.
- Any code path would emit AgentEvents without run id or tool call identity; if
  the chosen runtime exposes canonical trace context, dropping that trace also
  stops the slice.
- Instrumentation changes tool approval semantics or user-facing behavior.
- The implementation tries to collapse `AgentProvenanceEvent` into the
  generated UniFFI `AgentEvent`.

## Card 8 - Durable GraphEvent Mutation Mapping

Status on 2026-05-01:
PR1 durable EventStore mapping is closed. Swift now has
`DurableGraphEvent`, `DurableGraphEventKind`, and
`DurableGraphEventRelation`; EventStore now has a `graph_events` table with
bounded `saveGraphEvent(_:)`, `loadGraphEvent(eventID:)`, and
`graphEvents(mutationID:limit:)` APIs. Committed graph-affecting
`MutationEnvelope`s persist deterministic graph-event rows transactionally with
the envelope/outbox save. Pending/failed/reverted envelopes do not emit graph
events.

PR2 read-only Settings visibility is also closed. EventStore now exposes
bounded `graphEventDiagnostics()` for total rows, distinct mutations, latest
event metadata, and last kind, and Settings mounts `GraphEventVisibilityRow`
without repair, projection, graph renderer, retrieval, Halo, Theater, or Rust
OpLog side effects.

PR3 read-only projection snapshots are also closed. EventStore now exposes
bounded `recentGraphEvents(limit:)` for the latest durable graph-event window
in chronological projection order, and `DurableGraphEventProjection` folds
durable rows into deterministic read-only node/edge snapshots without graph
renderer, retrieval, Halo, Theater, Rust, OpLog, or UI side effects.

Naming note:
The durable model is intentionally named `DurableGraphEvent` because
`Epistemos/Engine/EventDrain.swift` already contains the 64-byte public
`GraphEvent` FFI ring-event type. Do not rename it without a gate that handles
that collision explicitly.

Goal:
Persist deterministic graph provenance from committed mutation envelopes before
any live graph, retrieval, Halo, Theater, or audit projection consumes it.

Authority to read first:
- `docs/fusion/deliberation/graph_event_durable_mapping_pr1_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/graph_event_visibility_pr2_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/graph_event_projection_snapshot_pr3_deliberation_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `/tmp/epistemos-graph-event-pr1-green-20260501-r1.log`
- `/tmp/epistemos-graph-event-visibility-pr2-final-20260501.log`
- `/tmp/epistemos-graph-event-projection-pr3-green-20260501.log`
- `Epistemos/Models/MutationEnvelope.swift`
- `Epistemos/State/EventStore.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `Epistemos/Views/Settings/GraphEventVisibilityRow.swift`
- `Epistemos/Engine/EventDrain.swift` only for the naming collision context.

Allowed write set:
- PR1 durable EventStore mapping: already closed.
- PR2 read-only Settings visibility: already closed.
- PR3 read-only projection snapshots: already closed.
- Future live GraphEvent consumer projections only after a new deliberation gate
  names exact projection files and focused tests.
- Docs under `docs/fusion/**`.

Forbidden write set:
- `Epistemos/Views/Graph/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- OpLog workers, Rust OpLog FFI, PipelineService, ChatCoordinator, Omega, hooks,
  protected note editor files, generated bindings, generated libraries, Xcode
  project files, entitlements, DerivedData, `.xcresult`, staging, commits,
  stashes, or branch operations unless a future gate names them.

Implementation contract:
- EventStore remains the durable Swift source for `graph_events`.
- Existing `MutationEnvelope` wire format must not change.
- Graph events derive only from committed graph-affecting mutation envelopes:
  `affectsGraph == true`, non-empty `relationChanges`, or
  `op == .graphMutation`.
- Event ids remain deterministic from `mutationID` plus an ordered index.
- Future projection slices may read `graph_events`; they must not mutate graph
  renderer/editor surfaces without a protected-path gate.
- PR2 already supplies bounded read-only Settings visibility through EventStore
  diagnostics. Do not add repair buttons, live projection, polling loops, raw
  Rust OpLog calls, or duplicate GraphEvent diagnostic rows in a future
  projection gate.
- PR3 already supplies deterministic read-only snapshot folding from durable
  GraphEvent rows. Future consumer gates may read that snapshot but must not
  mutate renderer, retrieval, Halo, Theater, or audit surfaces unless their
  gate names the exact files.

Tests and logs:
- Red log: `/tmp/epistemos-graph-event-pr1-red-20260501.log`.
- Green log: `/tmp/epistemos-graph-event-pr1-green-20260501-r1.log`.
- PR2 final green log:
  `/tmp/epistemos-graph-event-visibility-pr2-final-20260501.log`.
- PR3 red log:
  `/tmp/epistemos-graph-event-projection-pr3-red-20260501.log`.
- PR3 green log:
  `/tmp/epistemos-graph-event-projection-pr3-green-20260501.log`.
- Kimi audit attempt:
  `/tmp/epistemos-graph-event-pr1-kimi-audit-20260501-r1.log` produced no
  output and was terminated.
- Future projection PRs must write a failing test first for the selected
  consumer path, then a focused green Swift Testing log.
- Guardrails: `git diff --check`, source grep on implementation files for
  forbidden production paths, and protected-path name-only diff scan.

Acceptance:
- PR1 wired: durable typed model plus EventStore table/API.
- PR1 reachable: focused tests save, load, list, and idempotently update
  GraphEvent rows.
- PR1 visible: tests prove lower-snake-case JSON, bounded ordering, table
  creation, committed-envelope emission, and pending-envelope exclusion.
- PR2 wired/reachable/visible: Settings diagnostics expose total durable graph
  event rows, distinct mutation count, latest event metadata, and last event
  kind through read-only EventStore diagnostics.
- PR3 wired/reachable/visible: EventStore returns bounded recent GraphEvents in
  chronological projection order, and `DurableGraphEventProjection` folds
  node/edge create, update, label-change, delete, and generic graph-mutation
  rows deterministically without live consumer side effects.

Stop triggers:
- A live projection slice requires protected graph/editor/Rust files not named
  by its gate.
- The implementation needs to change `MutationEnvelope` wire format.
- Event ids become nondeterministic or not tied to a mutation id.
- The implementation tries to collapse `DurableGraphEvent` into the FFI
  `GraphEvent` ring type without a collision-resolution gate.

## Card 9 - Sovereign Gate Core Authorization

Status on 2026-05-02:
Core PR1 is closed. `Epistemos/Sovereign/SovereignGate.swift` is the single
Swift authorization executor and the only production source allowed to import
`LocalAuthentication` or instantiate `LAContext`. It executes externally
supplied requirements rather than deciding the app's action classes in Swift:
`.none` allows immediately, `.biometric(category:graceDuration:)` prompts with
category-scoped Sensitive grace, and `.deviceOwnerAuthentication` prompts every
time for Destructive-class presentation. The grace cache has explicit clearing,
does not cross categories, rejects empty reasons before prompting, does not
cache failed authentication, rejects non-finite / non-positive grace durations,
and does not survive clock rollback.

Lifecycle PR2 is also closed. `AppBootstrap` owns one shared `SovereignGate`,
starts/stops `SovereignGateLifecycleObserver`, and clears Sensitive grace on
app resign-active, app hide, workspace sleep, session resign-active, and screen
sleep. PR2 did not migrate existing dialogs, decide the action-class matrix in
Swift, touch Rust, touch generated transport, or add Pro/Research routes.

Goal:
Route future Core confirmation surfaces through one native macOS biometric gate
without parallel Touch ID prompts or Swift-owned policy matrices.

Authority to read first:
- `docs/fusion/deliberation/sovereign_gate_core_pr1_deliberation_2026_05_02.md`
- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §4.2 and Annex B
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `Epistemos/Sovereign/SovereignGate.swift`
- `EpistemosTests/SovereignGateTests.swift`
- `/tmp/epistemos-sovereign-gate-pr1-red-20260502.log`
- `/tmp/epistemos-sovereign-gate-pr1-green-20260502.log`
- `/tmp/epistemos-sovereign-gate-pr1-green-20260502-r2.log`
- `/tmp/epistemos-sovereign-gate-pr2-red-20260502.log`
- `/tmp/epistemos-sovereign-gate-pr2-green-20260502-r2.log`

Allowed write set:
- PR1 Swift executor and focused tests: already closed.
- PR2 app-owned lifecycle observer and focused tests: already closed.
- Future Rust action-class matrix only after a gate names exact Rust files
  and generated transport boundaries.
- Future lifecycle follow-up only after a gate names exact app lifecycle files
  not already covered by PR2 and proves no unrelated authorization migration.
- Future confirmation-surface migration PRs only after a gate names each exact
  existing surface and its focused tests.
- Docs under `docs/fusion/**`.

Forbidden write set:
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Notes/ProseTextView2.swift`
- `Epistemos/Views/Graph/**`
- `graph-engine/**`
- `agent_core/**` unless a future Rust matrix gate names exact files
- `epistemos-core/**` / generated UniFFI bindings unless a generated-transport
  gate names exact files
- Existing confirmation dialogs, Omega approvals, destructive vault actions,
  Settings footers, entitlements, Xcode project files, generated libraries,
  DerivedData, `.xcresult`, staging, commits, stashes, or branch operations
  unless the current gate explicitly includes them.

Implementation contract:
- `Epistemos/Sovereign/SovereignGate.swift` remains the only Swift source that
  touches `LocalAuthentication` / `LAContext`.
- Swift executes an externally supplied `SovereignGateRequirement`; it does not
  decide whether an app action is Trivial, Reversible, Sensitive, Destructive,
  or Sovereign.
- Sensitive grace is category-scoped, finite, positive, explicit-clearable, and
  invalidated by clock rollback.
- Destructive requirements use device-owner authentication every time and never
  receive grace.
- Lifecycle observers clear Sensitive grace on app/session/sleep boundaries and
  must be removable by `stop()`.
- Tests must use the injectable authenticator seam and never trigger real Touch
  ID.

Tests and logs:
- PR1 red log: `/tmp/epistemos-sovereign-gate-pr1-red-20260502.log`.
- PR1 green log:
  `/tmp/epistemos-sovereign-gate-pr1-green-20260502.log`.
- PR1 hardened green log:
  `/tmp/epistemos-sovereign-gate-pr1-green-20260502-r2.log`.
- PR2 red log: `/tmp/epistemos-sovereign-gate-pr2-red-20260502.log`.
- PR2 focused green log:
  `/tmp/epistemos-sovereign-gate-pr2-green-20260502-r2.log`.
- Guardrails: `git diff --check`, source grep proving LocalAuthentication /
  LAContext confinement, diff-only invariant greps, and staged protected-path
  scan.
- Future PRs must add a failing focused test first, then a focused green Swift
  Testing or Rust test log before staging.

Acceptance:
- PR1 wired: one Swift entrypoint executes Core-safe prompt requirements.
- PR1 reachable: focused tests cover no-auth, Sensitive grace, category
  boundaries, grace expiry, explicit clearing, destructive every-time auth,
  failed auth, empty reasons, clock rollback, and invalid grace durations.
- PR1 visible: source guard proves `LocalAuthentication` / `LAContext` are
  confined to `Epistemos/Sovereign/SovereignGate.swift`.
- PR1 boundary: no existing dialogs, Rust kernels, generated bindings,
  entitlements, protected graph/editor files, subprocesses, solver hot paths,
  tensor copies, or memory hot paths are touched.
- PR2 wired/reachable/visible: AppBootstrap owns and starts the lifecycle
  observer, focused tests prove app/system boundary clearing and `stop()`
  removal, and shell audit proves exact `start(gate: sovereignGate)` /
  `stop()` wiring.
- PR2 boundary: no existing dialogs, Rust kernels, generated bindings,
  entitlements, protected graph/editor files, subprocesses, solver hot paths,
  tensor copies, or memory hot paths are touched.

Stop triggers:
- A future slice needs generated UniFFI, Rust matrix, new lifecycle hooks, or
  existing dialog migration without naming exact files in a new gate.
- `LocalAuthentication`, `LAContext`, `canEvaluatePolicy`, `evaluatePolicy`,
  Touch ID, or biometric prompting appears outside
  `Epistemos/Sovereign/SovereignGate.swift`.
- Swift starts owning the app-action class matrix instead of executing the
  externally supplied requirement.
- Sensitive grace survives explicit clearing, crosses category boundaries,
  accepts invalid durations, survives clock rollback, or applies to destructive
  requirements.
