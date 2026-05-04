# Agent Build Workcards - 2026-05-01

## Purpose

This is the safe scaffolding pack for fast multi-agent implementation.

Do not scaffold broad fake APIs, empty placeholder systems, or "wire later"
stubs that encode guesses. The safe pattern is a vertical work card: each agent
gets source-of-truth docs, a narrow allowed write set, forbidden surfaces,
acceptance tests, evidence logs, and stop triggers. Codex then reviews the diff
and integrates only verified work.

## Master Research Index Rule

`docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` is the first read for any
feature, concept, mini-task, dependency choice, deletion, simplification,
worktree, or research-root question before a card is assigned or implemented.
Use §22 for the lookup procedure, §20 for worktree material, §21 for external
research roots, and §0 Honest Discoveries to correct older workcard or
fusion-packet claims.

If a card contradicts the master index, stop at the deliberation gate, verify
against current code/logs, and update the card or canon before building. Do not
resolve contradictions by guessing or by raw-merging donor worktrees.

Every card's "Authority To Read First" section must include the local
concept/source lookup from `MASTER_RESEARCH_INDEX_2026_05_02.md`. If that local
lookup does not provide a structured answer, or the card depends on current API,
framework, OS, model, package, App Store, or security behavior, add a targeted
web-validation line and prefer primary/official sources. Semantic expansion is
required: for example, "zero-copy" also means UMA, in-process, single-binary,
deterministic, no hot-path subprocess, direct/bare-metal path, and zero tensor
copies. Treat philosophy terms as implementation constraints, not vibes: the
goal is the shortest safe path from intent to execution.

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
does not claim tok/s yet. PR9 adds an app-hosted evidence ledger guard that
names the ten closed R15 JSON artifacts and keeps the open PR8 tok/s, renderer
FPS, and true Rust callback-loop artifacts explicitly forbidden from the closed
set. PR10 adds a debug-only true Rust-to-Swift callback-loop export baseline:
Rust loops over `AgentEventDelegate.on_text_delta`, Swift records the real JSON
artifact, source guards prove the Rust export is used, and the evidence ledger
now names 11 closed R15 artifacts while keeping MLX tok/s and renderer FPS
open. PR11 closes the offscreen live renderer FPS fixture through
`GraphEngine.render(width:height:)`, writes
`2026-05-02t00-00-00-000z-r15-renderer-fps-baseline-renderer_fps_thermal_soak.json`,
and marks `thermal_soak_status=not_five_min_thermal_soak` so it is not a
manual five-minute thermal-soak, renderer optimization, or product-runtime
claim. The evidence ledger now names 12 closed R15 artifacts while keeping MLX
tok/s open. Remaining specialized baseline for live MLX token throughput under
sufficient-memory/thermal-soak conditions stays open for a later fixture gate;
production GRDB/768d KNN still needs its own future gate before any product
claim.

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
- For PR9, cite
  `docs/fusion/deliberation/r15_benchmark_evidence_ledger_pr9_deliberation_2026_05_02.md`
  and `EpistemosTests/Benchmarks/R15BenchmarkEvidenceLedgerTests.swift` as the
  evidence-ledger guard only. It names closed artifact filenames and metadata,
  and it must not be weakened into a product benchmark or live-runtime claim.
- For PR10, cite
  `docs/fusion/deliberation/r15_true_rust_callback_loop_pr10_deliberation_2026_05_02.md`,
  `agent_core/src/bridge.rs`,
  `EpistemosTests/Benchmarks/UniFFICallbackThroughputTests.swift`, and
  `2026-05-02t00-00-00-000z-r15-true-rust-callback-loop-baseline-true_rust_callback_loop.json`
  as a debug-only true Rust-to-Swift callback-loop baseline. This does not
  claim a hot-path replacement, BoltFFI migration, graph/render speedup, or
  production session behavior change.
- For PR11, cite
  `docs/fusion/deliberation/r15_renderer_fps_baseline_pr11_deliberation_2026_05_02.md`,
  `EpistemosTests/Benchmarks/GraphFFIBenchmarkTests.swift`,
  `EpistemosTests/BenchmarkHarnessSourceGuardTests.swift`,
  `EpistemosTests/Benchmarks/R15BenchmarkEvidenceLedgerTests.swift`, and
  `2026-05-02t00-00-00-000z-r15-renderer-fps-baseline-renderer_fps_thermal_soak.json`
  as an offscreen live renderer FPS fixture baseline only. This does not claim
  a five-minute/manual thermal soak, production renderer optimization, or
  product runtime readiness.
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

Status on 2026-05-02:
Closed as the PR2 foundation slice, PR3A lease/retry foundation, and PR3B
dead-letter foundation. PR3C also closes the smallest production scheduling
worker shell. PR3D closes basic read-only Settings visibility for projection
health and dead letters. PR4A closes Swift-only read-only projection replay
snapshots and logical cutoff rollback inspection. PR4B closes read-only
cryptographic OpLog chain verification and expected-tip anchoring. PR5 closes
deterministic read-only ReplayBundle JSON export over replay snapshots. PR6
closes Swift-only read-only incremental replay over replay snapshots. PR7
closes read-only production ReplayBundle visibility in Settings. See:

- `docs/fusion/deliberation/eventstore_oplog_projection_pr2_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/eventstore_oplog_projection_lease_retry_pr3a_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/eventstore_oplog_projection_dead_letter_pr3b_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/eventstore_oplog_projection_worker_pr3c_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/eventstore_oplog_projection_visibility_pr3d_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/eventstore_oplog_replay_snapshot_pr4a_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/oplog_chain_verification_pr4b_deliberation_2026_05_01.md`
- `docs/fusion/deliberation/oplog_replay_bundle_export_pr5_deliberation_2026_05_02.md`
- `docs/fusion/deliberation/oplog_incremental_replay_pr6_deliberation_2026_05_02.md`
- `docs/fusion/deliberation/oplog_replay_bundle_production_visibility_pr7_deliberation_2026_05_02.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_038_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_041_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_042_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_044_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_045_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`

Do not assign agents to rebuild the basic projection scaffold. Future
provenance work should open new gates for live AgentEvent emission, GraphEvent
projection, or deeper audit/repair surfaces. Background projection worker scheduling is already
closed as PR3C.
Basic read-only dead-letter/projection visibility is already closed as PR3D.
Read-only projection replay snapshots are already closed as PR4A. Read-only
cryptographic chain verification is already closed as PR4B. Read-only
ReplayBundle export is already closed as PR5. Read-only incremental replay is
already closed as PR6. Read-only production ReplayBundle visibility is already
closed as PR7.

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
- PR5 already supplies deterministic read-only `MutationOpLogReplayBundle`
  export over replay snapshots through
  `RustOpLogFFIClient.exportMutationReplayBundle(...)`. Do not export raw
  `sourcePayloadJSON`, add a new raw ABI, execute rollback/repair, add UI, or
  wire production scheduling in future bundle gates.
- PR6 already supplies Swift-only read-only incremental replay:
  `MutationOpLogReplay.applyIncremental(...)` folds tail entries onto prior
  snapshots, drops overlap rows before counting, seeds duplicate detection from
  prior records, and
  `RustOpLogFFIClient.incrementalReplayMutationProjections(from:upToSeq:)`
  uses the existing `iterateAll()` / `iterate(after:)` bridge surface. Do not
  add rollback execution, repair, UI, production scheduling, or new raw ABI in
  future incremental-replay gates.
- PR7 already supplies read-only production ReplayBundle visibility:
  `MutationOpLogReplayBundleVisibilityReport` summarizes bounded counts/latest
  id for `OpLogProjectionHealthRow`. Do not add raw OpLog ABI calls, repair or
  export buttons, polling loops, timers, or private payload details in future
  visibility gates.
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
- PR5 ReplayBundle red evidence is
  `/tmp/epistemos-oplog-replay-bundle-pr5-red-20260502.log`.
- PR5 ReplayBundle green evidence is
  `/tmp/epistemos-oplog-replay-bundle-pr5-green-final-20260502.log`.
- PR6 incremental replay red evidence is
  `/tmp/epistemos-oplog-incremental-replay-pr6-red-20260502.log`.
- PR6 incremental replay green evidence is
  `/tmp/epistemos-oplog-incremental-replay-pr6-green-20260502.log`.
- PR7 production ReplayBundle visibility red evidence is
  `/tmp/epistemos-oplog-replay-bundle-visibility-pr7-red-20260502.log`.
- PR7 production ReplayBundle visibility green evidence is
  `/tmp/epistemos-oplog-replay-bundle-visibility-pr7-green-20260502.log`.
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
- ReplayBundle export: replay snapshots can be encoded as deterministic
  Codable JSON with records/duplicates/counts while omitting raw source payload
  JSON and without adding new raw ABI or mutation/repair behavior.
- Incremental replay: replay snapshots can be extended from tail OpLog entries
  with overlap rows dropped before counting, duplicate detection seeded from
  prior records, and ReplayBundle privacy preserved.
- Production ReplayBundle visibility: Settings can show bounded
  ReplayBundle counts/latest-id status from a sanitized report without raw ABI,
  repair/export UI, timers, polling, or private payload leakage.

Stop triggers:
- Projection requires protected editor or graph files.
- Projection bypasses `EventStore.saveMutationEnvelope`.
- Retry/idempotency cannot be proven.
- The implementation needs broad `agent_core` registry rewrites or generated
  binding edits.
- The slice starts adding UI, AgentEvent, or GraphEvent features instead of
  closing the projection contract.

## Card 7 - AgentEvent Tool Provenance

Status on 2026-05-02:
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
instrumentation.

PR5 read-only Settings visibility is also closed. EventStore exposes bounded
`agentEventDiagnostics()` for total rows, distinct runs, distinct tools, latest
event metadata, and last kind, and Settings mounts `AgentEventVisibilityRow`
as a diagnostic-only surface. Do not assign another agent to rebuild this
same AgentEvent visibility row.

PR6 Pipeline HookRegistry production mount is also closed. `PipelineService`
now calls the existing HookRegistry at the local tool-loop prompt-build
boundary, before observed local tool calls, and after observed local tool
results. The mount preserves no-hook behavior and does not change approval
policy, routing, UI, ChatCoordinator, Omega, graph, Rust, generated bindings,
EventStore schema, or provider-native/direct-stream paths.

PR7 Omega ReasoningLoop internal tool-call provenance is also closed.
ReasoningLoop now records requested, started, and completed-or-failed
AgentEvents around its existing internal `vault_search` / `graph_search` calls
with per-run `reasoning-loop-...` ids and `omega-reasoning-loop` actor
metadata, without changing approval, routing, UI, HookRegistry,
ChatCoordinator, PipelineService, graph, Rust, generated bindings, or
EventStore schema.

PR8 CloudLLM non-streaming cloud generation provenance is also closed.
`CloudLLMClient.generate(...)` now records requested, started, and
completed/failed AgentEvents for direct cloud-provider generation with
`cloud-llm-...` run ids, `cloud-llm-client` actor metadata, and sanitized
provider/model/mode/route payloads. Prompt bodies, system prompts, credentials,
request bodies, URLs, and generated answer text are intentionally excluded.
This records the cloud-provider surface as `hermesGateway` class without adding
a Hermes subprocess adapter or changing provider routing.

PR9 CloudLLM direct cloud streaming provenance is also closed.
`CloudLLMClient.stream(...)` now records requested, started, and
completed/failed AgentEvents for direct cloud-provider streaming with
`cloud-llm-...` run ids, `cloud-llm-client` actor metadata, and sanitized
provider/model/mode/route payloads. Results record only chunk count and output
byte count, never streamed text. This records the streaming surface as
`hermesGateway` class without changing provider routing, SSE parsing, sinks, or
adding a Hermes subprocess adapter.

PR10 CloudLLM provider-native structured-output provenance is also closed.
`CloudLLMClient.generateStructured(...)` now records requested, started, and
completed/failed AgentEvents for structured cloud generation with
`cloud-llm-...` run ids, `cloud-llm-client` actor metadata, and sanitized
provider/model/mode/schema/route payloads. Results record only raw JSON byte
and length counts, never the returned structured JSON contents. This records
the structured-output surface as `hermesGateway` class without changing
provider routing, schema request construction, fallback prompt behavior, or
adding a Hermes subprocess adapter.

PR11 LocalAgentLoop tool execution provenance is also closed.
`LocalAgentLoop` now records requested, started, and completed/failed
AgentEvents for parsed local tool calls with `local-agent-...` run ids,
`local-agent-loop` actor metadata, `local-agent-tool:N` sequence ids,
source/surface metadata, and bounded result/error payloads. This preserves
model routing, tool parsing, tool execution, repair semantics, approvals, UI,
provider calls, HookRegistry, PipelineService, ChatCoordinator, Omega, graph,
Rust, generated bindings, and EventStore schema.

PR12 DriverChannelToolExecutor channel provenance is also closed.
`DriverChannelToolExecutor.execute(...)` now records requested, started, and
completed/failed AgentEvents for channel-driver tool wrappers with
`driver-channel-...` run ids, `driver-channel-<channel>` actor metadata,
`driver-channel-tool:1` ids, source/surface/channel/tier metadata, and bounded
result/error payloads. This preserves channel adapter payload construction,
contact routing fallback, LocalAgentLoop, PipelineService, ChatCoordinator,
Omega reasoning, graph, Rust, generated bindings, approval, UI, provider
routing, and EventStore schema.

PR13 remote relay channel provenance is also closed.
`RemoteRelayChannelAdapter` now routes relay send/fetch/list/audit HTTP calls
through a URLSession-injectable relay client that records requested, started,
and completed/failed AgentEvents with `relay-channel-...` run ids,
`relay-channel-<channel>` actor metadata, `relay-channel-tool:1` ids,
source/surface/channel/route/method metadata, and sanitized result/error
payloads. Tests prove message text, relay endpoint hosts, relay credentials,
sender identity values, relay response bodies, and HTTP error bodies are not
persisted in provenance. This preserves relay payload construction, parser
behavior, native fallback, DriverChannelToolExecutor, LocalAgentLoop,
PipelineService, ChatCoordinator, Omega, graph, Rust, generated bindings,
approval, UI, provider routing, and EventStore schema.

PR14 AgentGrep search provenance is also closed.
`AgentGrepService.search(query:kindFilter:limit:)` now records requested,
started, and completed/failed AgentEvents with `agent-grep-...` run ids,
`agent-grep-search:1` tool identity, source/surface metadata, bounded kind
filter, limit, hit count, and backend failure class. Persisted provenance
excludes query text, snippets, vault-relative paths, file bodies, source text,
sidecar provenance ids, and tool-use ids. This preserves search behavior,
sidecar enrichment, indexing, unindexing, UI, approval, routing, graph, Rust,
generated bindings, and EventStore schema.

PR15 AgentQueryEngine backend-stream provenance is also closed.
`AgentQueryEngine` now records requested, started, and completed/failed
AgentEvents for backend `.toolUse` / `.toolResult` stream events with
`agent-query-engine-...` run ids, `agent-query-engine` actor metadata,
backend/model/turn/tool metadata, output byte counts, and error flags.
Persisted provenance excludes prompt bodies, chat history, system prompts, cwd,
backend tool inputs, backend tool outputs, raw text, thinking text, and session
ids. This preserves backend streaming, prompt construction, approval, UI,
provider routing, ChatCoordinator, PipelineService, LocalAgentLoop, LLMService,
Omega, graph, Rust, generated bindings, and EventStore schema.

PR16 InstantRecall sync recall provenance is also closed.
`InstantRecallService.search(queryText:topK:)` now records requested, started,
and completed/failed AgentEvents for valid sync recall searches with
`instant-recall-...` run ids, `instant-recall-service` actor metadata,
`instant-recall-search:N` ids, source/surface/topK/query-count metadata,
hit/document counts, elapsed milliseconds, and bounded failure classes.
Persisted provenance excludes query text, note ids, note bodies, result text,
snippets, vault paths, source text, async recall events, Halo, ShadowSearch,
editor state, and graph state. This preserves recall behavior, hydration,
metrics, async recall, Halo, ShadowSearch, UI, approval, routing, graph, Rust,
generated bindings, and EventStore schema.

PR17 InstantRecall async recall provenance is also closed.
`InstantRecallService.searchAsync(query:topK:)` now records requested, started,
and completed/failed AgentEvents for valid async recall searches with
`instant-recall-async-...` run ids, `instant-recall-service` actor metadata,
independent `instant-recall-search-async:N` ids,
`surface=instant_recall_async`, query-count/topK metadata, hit/document counts,
FFI-only elapsed milliseconds, typed async failure classes, zero-hit completed
rows, and cancellation terminal rows. Persisted provenance excludes query text,
note ids, note bodies, result text, snippets, vault paths, source text, scores,
embeddings, raw FFI JSON, localized error descriptions, Halo, ShadowSearch,
editor state, and graph state. This preserves async recall behavior, hydration,
MainActor metrics, UI, approval, routing, graph, Rust, generated bindings, and
EventStore schema.

PR18 ShadowSearch backend provenance is also closed.
`ShadowSearchService.search(text:domain:limit:)` now records requested, started,
and completed/failed AgentEvents for valid ambient ShadowSearch calls with
`shadow-search-...` run ids, `shadow-search-service` actor metadata,
per-instance `shadow-search:N` ids, `surface=shadow_search`,
domain/limit/query-count metadata, hit counts, elapsed milliseconds, zero-hit
completed rows, cancellation failed rows, and closed ShadowFFI failure classes.
Persisted provenance excludes query text, hit ids, titles, snippets, scores,
source labels, document bodies, vault paths, raw FFI payloads, localized
descriptions, and arbitrary error text. This preserves ShadowSearch hit
behavior, catch-to-empty behavior, `searchOrThrow`, `stats`, Halo,
ContextualShadowsState, UI, graph, Rust, generated bindings, and EventStore
schema.

PR19 SearchIndex fused async provenance is also closed.
`SearchIndexService.fusedSearchAsync(query:weights:now:)` now records
requested, started, and completed/failed AgentEvents for valid non-empty async
RRF fused-search calls with `search-index-fused-async-...` run ids,
`search-index-service` actor metadata, per-instance
`search-index-fused-async:N` ids, `surface=fused_search_async`, query character
count, term count, `weights_profile=default|custom`, now timestamp, hit count,
elapsed milliseconds, zero-hit completed events, cancellation terminal events,
and closed `cancelled|sql_error|unknown_error` failure classes. Persisted
provenance excludes query text, sanitized FTS query, hit ids, titles, snippets,
scores, source labels, document bodies, vault paths, SQL, GRDB error strings,
localized descriptions, scalar weight values, and arbitrary error text. Source
and behavior stay away from sync `fusedSearch`, RRF SQL, VaultSyncService, UI,
graph, Rust, generated bindings, and EventStore schema. Expanded verification
passes 55 selected tests across `RRFFusionQueryTests`,
`ReadableBlocksIndexTests`, `ReadableBlocksProjectorTests`, and the non-gated
SearchIndex source guard; the focused runtime tests compile on this host but
remain skipped by the pre-existing FTS5 availability gate.

PR0 sync recorder enabler is also closed. `AgentToolProvenanceRecorder` now
shares event construction with a nonisolated `AgentToolProvenanceSyncRecorder`
that can persist ordered AgentEvents from synchronous callers without
main-actor bridge patterns. The enabler intentionally does not instrument
`SearchIndexService.fusedSearch(...)`; PR20 consumed
`AgentToolProvenanceSyncRecorder` under a separate deliberation gate with fresh
tests for sync fused-search behavior and privacy bounds.

PR20 SearchIndex fused sync provenance is also closed.
`SearchIndexService.fusedSearch(query:weights:now:)` now records requested,
started, and completed/failed AgentEvents for valid non-empty sync RRF
fused-search calls with `search-index-fused-sync-...` run ids,
`search-index-service` actor metadata, per-instance
`search-index-fused-sync:N` ids, `surface=fused_search`, query character count,
term count, `weights_profile=default|custom`, now timestamp, hit count, elapsed
milliseconds, zero-hit completed events, and closed
`cancelled|sql_error|unknown_error` failure classes. Persisted provenance
excludes query text, sanitized FTS query, hit ids, titles, snippets, scores,
source labels, document bodies, vault paths, SQL, GRDB error strings, localized
descriptions, scalar weight values, and arbitrary error text. Source and
behavior stay away from RRF SQL, VaultSyncService, QueryRuntime, UI, graph,
Rust, generated bindings, and EventStore schema. Focused source-guard
verification passes on this host; the focused runtime tests compile but remain
skipped by the pre-existing FTS5 availability gate.

PR21 SearchIndex direct page sync/async provenance is also closed.
`SearchIndexService.search(query:limit:)` and
`SearchIndexService.searchAsync(query:limit:)` now record requested, started,
and completed/failed AgentEvents for valid non-empty direct page searches with
`search-index-page-sync-...` / `search-index-page-async-...` run ids,
`search-index-service` actor metadata, per-instance
`search-index-page-sync:N` / `search-index-page-async:N` ids,
`surface=search|search_async`, query character count, term count, limit, hit
count, elapsed milliseconds, zero-hit completed events, and closed
`cancelled|sql_error|unknown_error` failure classes. Persisted provenance
excludes query text, sanitized FTS query, hit ids, titles, snippets, scores,
source labels, document bodies, vault paths, SQL, GRDB error strings, localized
descriptions, arbitrary error text, and block-search tool names. Source and
behavior stay away from page-search SQL, block search, fused search,
VaultSyncService, QueryRuntime, UI, graph, Rust, generated bindings, and
EventStore schema. Focused source-guard verification passes under `pipefail`;
the focused runtime tests compile but remain skipped by the pre-existing FTS5
availability gate.

PR22 SearchIndex block search sync/async provenance is also closed.
`SearchIndexService.searchBlocks(query:limit:)` and
`SearchIndexService.searchBlocksAsync(query:limit:)` now record requested,
started, and completed/failed AgentEvents for valid non-empty block searches
with `search-index-block-sync-...` / `search-index-block-async-...` run ids,
`search-index-service` actor metadata, per-instance
`search-index-block-sync:N` / `search-index-block-async:N` ids,
`surface=search_blocks|search_blocks_async`, query character count, term count,
limit, hit count, elapsed milliseconds, zero-hit completed events, and closed
`cancelled|sql_error|unknown_error` failure classes. Persisted provenance
excludes query text, sanitized FTS query, block ids, page ids, titles, snippets,
ranks, document bodies, vault paths, SQL, GRDB error strings, localized
descriptions, arbitrary error text, direct-page tool names, and fused-search
tool names. Source and behavior stay away from block-search SQL, page search,
fused search, VaultSyncService, QueryRuntime, UI, graph, Rust, generated
bindings, and EventStore schema. Focused source-guard verification passes under
`pipefail`; the focused runtime tests compile but remain skipped by the
pre-existing FTS5 availability gate.

PR23 MLX image-generation attempt provenance is also closed.
`MLXImageGenerationService.generate(prompt:aspectRatio:)` now records requested,
started, and completed/failed AgentEvents around the current honest
attempt-and-explicit-failure scaffold with `mlx-image-generation-...` run ids,
`mlx-image-generation-service` actor metadata, per-service
`mlx-image-generation:N` tool call ids, `image_generate.mlx` tool name,
`source=mlx_image_generation_service`, `surface=image_generate`, `provider=mlx`,
aspect ratio, prompt character count, elapsed milliseconds, success boolean, and
bounded `flux_pipeline_unavailable|unknown_error` failure classes. Persisted
provenance excludes prompt text, generated image path, model id, FAL hints,
localized descriptions, arbitrary error text, cloud routing, and filesystem
paths. Source and behavior stay away from real Flux wiring, cloud provider
selection, UI, graph, Rust, generated bindings, EventStore schema, Hermes, MCP,
subprocesses, and ANE/private API work. Focused runtime verification passes
under `pipefail`.

PR24 LocalGGUF non-streaming generate provenance is also closed.
`LocalGGUFClient.generate(...)` now records requested, started, and
completed/failed AgentEvents for the non-streaming GGUF generation path with
`local-gguf-generate-...` run ids, `local-gguf-client` actor metadata,
per-client `local-gguf-generate:N` tool call ids, `local_generate.gguf` tool
name, `source=local_gguf_client`, `surface=generate`, `provider=local_gguf`,
requested/resolved runtime, reasoning mode, max token count, prompt/system
prompt character counts, steering-hints presence, elapsed milliseconds, output
character count, success boolean, and bounded `backend_failure` terminal failure
class. Persisted provenance excludes prompt text, system prompts, steering hint
JSON, generated output, model id, artifact id, filesystem paths, localized
descriptions, and arbitrary error text. Source and behavior stay away from GGUF
streaming, routing semantics, model loading, runtime control-plane state
semantics, UI, graph, Rust, generated bindings, EventStore schema, Hermes, MCP,
subprocesses, browser/computer-use surfaces, LocalAuthentication, and ANE/private
API work. Focused runtime verification passes under `pipefail`.

PR25 LocalBackend stream provenance is also closed.
`LocalBackendLLMClient.stream(...)` now records requested, started, and
completed/failed AgentEvents for the local backend stream router with
`local-backend-stream-...` run ids, `local-backend-llm-client` actor metadata,
per-router `local-backend-stream:N` tool call ids, `local_backend.stream` tool
name, `source=local_backend_llm_client`, `surface=stream`,
`provider=local_backend`, requested/resolved runtime, reasoning mode, max token
count, prompt/system prompt character counts, steering-hints presence, elapsed
milliseconds, chunk count, output character count, success boolean, and bounded
`cancelled|model_required|runtime_unavailable|model_unavailable|backend_failure`
failure classes. Persisted provenance excludes prompt text, system prompts,
steering hint JSON, streamed output, model id, artifact id, filesystem paths,
localized descriptions, arbitrary error text, Hermes/MCP/subprocess surfaces,
browser/computer-use surfaces, LocalAuthentication, and ANE/private API details.
Source and behavior stay away from non-streaming generate, stream routing
semantics, token delivery, lower GGUF/MLX runtime behavior, runtime control-plane
policy, UI, graph, Rust, generated bindings, and EventStore schema. Focused
runtime verification passes under `pipefail`.

PR26 local runtime recorder mount is also closed.
`AppBootstrap` now constructs one shared `AgentToolProvenanceRecorder` for local
runtime clients and passes it to `LocalGGUFClient` and `LocalBackendLLMClient`,
making PR24/PR25 reachable in normal app boot. It intentionally does not
instrument `LocalBackendLLMClient.generate(...)`, claim MLX text-generation
provenance, change routing, EventStore schema, UI, graph, Rust, generated
bindings, Hermes/MCP, Sovereign, or ANE/private API surfaces. Focused
source-guard verification passes under `pipefail`.

PR27 LocalMLX direct generate provenance is also closed.
`LocalMLXClient.generate(...)` now records requested, started, and
completed/failed AgentEvents for direct MLX text generation with
`local-mlx-generate-...` run ids, `local-mlx-client` actor metadata, per-client
`local-mlx-generate:N` tool call ids, `local_generate.mlx` tool name,
`source=local_mlx_client`, `surface=generate`, `provider=local_mlx`,
requested/resolved runtime, reasoning mode, max token count, prompt/system
prompt character counts, steering-hints presence, elapsed milliseconds, output
character count, success boolean, and bounded control-plane/backend failure
classes. Persisted provenance excludes prompt text, system prompts, steering
hint JSON, generated output, model id, artifact id, image URLs, filesystem
paths, localized descriptions, arbitrary error text, Hermes/MCP/subprocess
surfaces, browser/computer-use surfaces, LocalAuthentication, and ANE/private
API details. Source and behavior stay away from stream behavior, routing
semantics, model loading, runtime control-plane policy, UI, graph, Rust,
generated bindings, and EventStore schema. Focused runtime verification passes
under `pipefail`.

PR28 LocalMLX direct stream provenance is also closed.
`LocalMLXClient.stream(...)` now records requested, started, and
completed/failed/cancelled AgentEvents for direct MLX streaming with
`local-mlx-stream-...` run ids, `local-mlx-client` actor metadata, per-client
`local-mlx-stream:N` tool call ids, `local_stream.mlx` tool name,
`source=local_mlx_client`, `surface=stream`, `provider=local_mlx`,
requested/resolved runtime, reasoning mode, max token count, prompt/system
prompt character counts, steering-hints presence, elapsed milliseconds, output
character count, streamed chunk count, success boolean, and bounded
control-plane/backend/cancelled failure classes. Persisted provenance excludes
prompt text, system prompts, steering hint JSON, streamed output, model id,
artifact id, image URLs, filesystem paths, localized descriptions, arbitrary
error text, Hermes/MCP/subprocess surfaces, browser/computer-use surfaces,
LocalAuthentication, and ANE/private API details. Source and behavior stay away
from routing semantics, token delivery, model loading, runtime control-plane
policy, lower runtime semantics, UI, graph, Rust, generated bindings, and
EventStore schema. Focused runtime verification passes under `pipefail`; the
runtime-control-plane UniFFI cancellation cleanup issue exposed by this slice is
now closed by Runtime Contract PR30.

PR29 LocalBackend direct generate provenance is also closed.
`LocalBackendLLMClient.generate(...)` now records router-level requested,
started, and completed/failed AgentEvents for local backend non-streaming
generation with `local-backend-generate-...` run ids,
`local-backend-llm-client` actor metadata, per-router
`local-backend-generate:N` tool call ids, `local_backend.generate` tool name,
`source=local_backend_llm_client`, `surface=generate`,
`provider=local_backend`, requested/resolved runtime, reasoning mode, max token
count, prompt/system prompt character counts, steering-hints presence, elapsed
milliseconds, output character count, success boolean, and bounded
`cancelled|model_required|runtime_unavailable|model_unavailable|backend_failure`
failure classes. Persisted provenance excludes prompt text, system prompts,
steering hint JSON, generated output, model id, artifact id, filesystem paths,
localized descriptions, arbitrary error text, Hermes/MCP/subprocess surfaces,
browser/computer-use surfaces, LocalAuthentication, and ANE/private API details.
Source and behavior stay away from routing policy changes, lower GGUF/MLX
runtime behavior, model loading, UI, graph, Rust, generated bindings, and
EventStore schema. Focused runtime verification passes under `pipefail`; the
runtime-control-plane UniFFI cancellation cleanup issue exposed through the
older MLX stream cancellation test is now closed by Runtime Contract PR30.

PR30 Runtime Contract error-class bridge is also closed.
`RuntimeGenerationSummary.error_class`, `RuntimeGenerationEvent.error_class`,
and `finish_failed(error_class:)` now cross the generated UniFFI boundary as
bounded raw strings, while Swift maps them back into
`BackendRuntimeContractError` and Rust still throws typed
`RuntimeContractError` for contract failures. This removes the repeated
`Can't lift flat errors` cleanup panic from failed/cancelled terminal-event
polling without changing runtime policy, model loading, EventStore schema,
AgentEvent persistence, UI, graph, or lower GGUF/MLX semantics. Focused
`BackendRuntimeContractTests` pass under `pipefail`.

PR32 LocalGGUF direct stream provenance is also closed.
`LocalGGUFClient.stream(...)` now records direct GGUF streaming requested,
started, and completed/failed AgentEvents with `local-gguf-stream-...` run ids,
`local-gguf-client` actor metadata, per-client `local-gguf-stream:N` tool call
ids, `local_stream.gguf` tool name, `source=local_gguf_client`,
`surface=stream`, `provider=local_gguf`, requested/resolved runtime, reasoning
mode, max token count, prompt/system prompt character counts, steering-hints
presence, elapsed milliseconds, chunk count, output character count, success
boolean, and bounded
`cancelled|runtime_unavailable|model_not_loaded|model_not_found|backend_failure`
failure classes. Persisted provenance excludes prompt text, system prompts,
steering hint JSON, streamed output, model id, artifact id, filesystem paths,
localized descriptions, arbitrary error text, Hermes/MCP/subprocess surfaces,
browser/computer-use surfaces, LocalAuthentication, and ANE/private API
details. Source and behavior stay away from routing semantics, token delivery,
model loading, runtime-control-plane policy, lower runtime semantics, UI, graph,
Rust, generated bindings, and EventStore schema. Focused `LocalGGUFClientTests`
pass under `pipefail` with isolated DerivedData after stale Xcode build
processes were cleaned up.

PR33 Apple Intelligence direct generate provenance is also closed.
`AppleIntelligenceService.generate(...)` now records direct Apple Intelligence
generation requested, started, and completed/failed AgentEvents with
`apple-intelligence-generate-...` run ids, `apple-intelligence-service` actor
metadata, per-service `apple-intelligence-generate:N` tool call ids,
`apple_intelligence.generate` tool name, `source=apple_intelligence_service`,
`surface=generate`, `provider=apple_intelligence`, prompt/system/resolved
system prompt character counts, augmented-system-prompt presence, elapsed
milliseconds, output character count, success boolean, and bounded
`unavailable|thermal_pause|cancelled|generation_failed` failure classes.
Persisted provenance excludes prompt text, system prompts, augmented vault
context, generated output, localized descriptions, arbitrary backend error
text, Hermes/MCP/subprocess surfaces, browser/computer-use surfaces,
LocalAuthentication, and ANE/private API details. Source and behavior stay away
from FoundationModels routing, thermal guard behavior, circuit-breaker
behavior, session recycling, prompt-vault augmentation, availability checks,
UI, graph, Rust, generated bindings, and EventStore schema. Focused
`AppleIntelligenceServiceAgentEventTests` pass under `pipefail` with isolated
DerivedData after the expected red failure proved the missing test seam.

PR34 AgentEvent v1.6 forward vocabulary is also closed as vocabulary-only.
`AgentProvenanceEventKind` now contains the six simulation doctrine forward
kinds `steer_requested`, `summary_started`, `summary_delta`,
`summary_completed`, `vault_created`, and `vault_archived`. Focused tests prove
CaseIterable membership, Codable round-trip, and EventStore persistence as
tool-less `forward_variant_only` rows. This does not implement dispatch-panel
steering, helper-model summary streams, multi-vault UI, Rust simulation enum
variants, Swift stream events, generated bindings, emitters, or EventStore
schema changes.

PR35 AgentEvent MCPBridge Core `tools/call` denial provenance is also closed.
`MCPBridge.dispatch(_:distribution:)` now records sanitized requested/denied
AgentEvents when Core/App Store policy rejects a hidden Pro gateway tool before
Rust dispatch. The persisted rows use `mcp-bridge-policy-gate` run ids,
synthetic `mcp-policy-denial:N` tool-call ids, `mcp_bridge_policy_gate`
metadata, fixed sanitized arguments JSON, nil result JSON, and a generic denial
error. Focused tests prove denied calls still return JSON-RPC `-32601`,
Core-safe and Pro/Research calls do not emit false policy-denial provenance,
and raw request bodies, `params.arguments`, command strings, filesystem paths,
result payloads, request ids, localized descriptions, and arbitrary denial
text are not persisted. This does not change Rust MCP dispatch, provider
behavior, subprocess launchers, UI, graph, EventStore schema, Sovereign,
generated bindings, or ANE/private API surfaces.

PR36 AgentEvent Phase7 NightBrain trigger provenance is also closed.
`Phase7Bridge.triggerNightbrainJob(jobType:priority:)` now records sanitized
requested/started/completed/failed AgentEvents for supported, unsupported,
bootstrap-unavailable, disabled-agent, and deferred-pipeline outcomes. Persisted
metadata uses the `phase7-nightbrain-trigger` run id, synthetic
`phase7-nightbrain-trigger:N` tool-call ids, `nightbrain_trigger` tool name,
canonical supported job values, bounded priority classes,
`requested_job_supported`, `success`, result, duration, and bounded failure
classes. Focused tests prove unsupported jobs fail before bootstrap lookup,
bootstrap-unavailable failures are generic, existing job aliases stay intact,
and raw job strings, filesystem paths, priority text, bootstrap/internal errors,
localized descriptions, Hermes/MCP/subprocess surfaces, browser/computer-use
surfaces, LocalAuthentication, and ANE/private API details are not persisted.
This does not change NightBrain scheduling semantics, AppBootstrap lifecycle,
EventStore schema, UI, graph, Rust, generated bindings, Sovereign, Hermes/MCP,
subprocess, browser/computer-use, or ANE/private API surfaces.

PR37 AgentEvent Phase5 SSM state provenance is also closed.
`Phase5Bridge.manageSsmState(actionJson:)` now records sanitized
requested/started/completed/failed AgentEvents for SSM state `list`, `prune`,
`total_size`, invalid JSON, unsupported action, bootstrap-unavailable, and
live-cache-only `save`/`load` outcomes. Persisted rows use the
`phase5-ssm-state` run id, synthetic `phase5-ssm-state:N` tool-call ids,
`ssm_state_manage` tool name, bounded action classes, model scope, clamped
`keep_count`, scalar result counts/bytes, duration, success status, and bounded
failure classes including `live_cache_action_unavailable`. Focused tests prove
the bridge does not persist raw action JSON, model ids, cache/state paths,
state URLs, session ids, timestamps, localized descriptions, or
bootstrap/internal errors into AgentEvents. This does not change live SSM cache
ownership, `SSMStateService` internals, generation, UI, graph, Rust, generated
bindings, EventStore schema, Sovereign, Hermes/MCP, subprocess,
browser/computer-use, or ANE/private API surfaces.

PR39 AgentEvent ComputerUseBridge provenance is also closed.
`ComputerUseBridge.execute(actionJSON:)` now records sanitized
requested/started/completed/failed AgentEvents around existing computer-use
actions. Persisted rows use the `computer-use-bridge` run id, synthetic
`computer-use-bridge:N` tool-call ids, `computer.<action_class>` tool names,
bounded action classes, coordinate buckets, text-length buckets,
direction/key/app-scope classes, result classes, screenshot-included booleans,
accessibility element counts, duration, success status, and bounded failure
classes. Focused tests prove raw action JSON, screenshots/base64 payloads,
accessibility tree text, typed text, app names, exact coordinates, raw results,
localized descriptions, and arbitrary error strings are not persisted in
AgentEvents. This does not change Computer Use execution, Core/MAS tool policy,
MCP/Hermes routing, UI, graph, EventStore schema, Sovereign, generated bindings,
subprocess surfaces, or ANE/private API surfaces.

PR40 AgentEvent Phase4 perceive provenance is also closed.
`Phase4Bridge.perceive(appName:depth:)` now records sanitized
requested/started/completed/failed AgentEvents around existing Screen2AX
perception. Persisted rows use the `phase4-perceive` run id, synthetic
`phase4-perceive:N` tool-call ids, the `phase4.perceive` tool name, bounded
depth classes, app-scope class, perception method, scalar interactive/OCR
counts, rounded latency, duration, success status, and bounded failure classes.
Focused tests prove raw AX tree JSON, OCR text, app names, raw depth strings,
user paths, raw perception results, localized descriptions, and arbitrary
errors are not persisted in AgentEvents. This does not change returned
perception payloads, `interact`, `screen_watch`, Computer Use execution,
Core/MAS tool policy, MCP/Hermes routing, UI, graph, EventStore schema,
Sovereign, generated bindings, subprocess surfaces, or ANE/private API
surfaces.

PR41 AgentEvent Phase4 interact provenance is also closed.
`Phase4Bridge.interact(actionJson:)` now records sanitized
requested/started/completed/failed AgentEvents around existing
ComputerUseBridge/AXorcist dispatch. Persisted rows use the `phase4-interact`
run id, synthetic `phase4-interact:N` tool-call ids,
`phase4.interact.<action_class>` tool names, bounded action classes, route
classes, app/target scopes, value-length buckets, coordinate buckets,
direction/key classes, scalar duration, success status, result classes, and
bounded failure classes. Focused tests prove raw action JSON, typed text, target
labels, bundle ids, raw coordinates, raw returned payloads, user paths,
localized descriptions, and arbitrary errors are not persisted in AgentEvents.
This does not change returned interaction payloads, `perceive`, `screen_watch`,
Computer Use execution, AXorcist behavior, Core/MAS tool policy, MCP/Hermes
routing, UI, graph, EventStore schema, Sovereign, generated bindings,
subprocess surfaces, or ANE/private API surfaces.

PR42 AgentEvent Phase4 screen_watch provenance is also closed.
`Phase4Bridge.startScreenWatch(watchJson:)` now records sanitized
requested/started/completed/failed AgentEvents around existing AX/file/timeout
watch behavior. Persisted rows use the `phase4-screen-watch` run id, synthetic
`phase4-screen-watch:N` tool-call ids, `phase4.screen_watch.<mode_class>` tool
names, bounded mode classes, app/target scopes, timeout buckets, poll-interval
buckets, scalar duration, triggered state, reason classes, and bounded failure
classes. Focused tests prove raw watch JSON, file paths, target strings, bundle
ids, raw AX payloads, localized descriptions, arbitrary errors, and per-poll
state are not persisted in AgentEvents. This does not change returned watch
payloads, `perceive`, `interact`, Computer Use execution, AXorcist behavior,
Core/MAS tool policy, MCP/Hermes routing, UI, graph, EventStore schema,
Sovereign, generated bindings, subprocess surfaces, or ANE/private API
surfaces.

PR43 AgentEvent ClarifyPromptBridge provenance is also closed.
`ClarifyPromptBridge.ask(questionJson:)` now records sanitized
requested/started/completed AgentEvents around the existing Rust clarify
callback to native NSAlert path. Persisted rows use the `clarify-prompt` run id,
synthetic `clarify-prompt:N` tool-call ids, `clarify.ask.<input_mode>` tool
names, bounded input mode, question scope, choice-count bucket, payload class,
result class, response-length bucket, selected choice index, and scalar
duration. Focused tests prove raw question JSON, questions, choices, answers,
filesystem paths, prompt text, and arbitrary errors are not persisted in
AgentEvents. This does not change returned clarify response JSON, prompt UI,
Core/MAS tool policy, MCP/Hermes routing, Sovereign, graph, EventStore schema,
generated bindings, subprocess surfaces, or ANE/private API surfaces.

PR44 AgentEvent Bridge no-double-count source guard is also closed.
`AgentEventBridgeNoDoubleCountSourceGuardTests` now reads the four intentional
no-instrument Bridge surfaces: `StreamingDelegate.swift`,
`ChunkedMCPFraming.swift`, `CoTStreamInterceptor.swift`, and
`ToolTierBridge.swift`. The suite fails if any of those
transport/parser/router/policy surfaces directly instantiate
`AgentToolProvenanceRecorder` or call `recordToolEvent`. This preserves the
post-PR43 Bridge-complete boundary and keeps future AgentEvent expansion aimed
at Omega runtime + LocalAgent instead of lower Bridge layers. This does not
change production source, EventStore schema, Core/MAS policy, MCP/Hermes
routing, Sovereign, graph, generated bindings, subprocess surfaces, or
ANE/private API surfaces.

PR45 AgentEvent GhostComputerAgent reachability guard is also closed.
`GhostComputerAgentReachabilityGuardTests` now proves production Swift does not
instantiate `GhostComputerAgent`, does not call its static MCP adapters, and
keeps the shipping computer-use route on `ComputerUseBridge` from both
`Phase4Bridge` and `StreamingDelegate` while Rust delegates `name == "computer"`
through the native computer-action callback. The LocalAgent reflex/EOF
completion candidate was audited as closed by Kimi: EOF flush is plaintext
only, fallback parsing still enters `executeToolCall`, and requested tool
events still reach completed or failed terminal events. If production routing
ever starts using `GhostComputerAgent`, open a fresh provenance slice first.
This does not change production source, EventStore schema, Core/MAS policy,
MCP/Hermes routing, Sovereign, graph, generated bindings, subprocess surfaces,
or ANE/private API surfaces.

PR46 GhostComputerAgent dead-code deletion is also closed. Claude's detective
resolutions found the source was superseded by `ComputerUseBridge` and had no
production callers, so `Epistemos/Omega/Agents/GhostComputerAgent.swift` was
deleted instead of instrumented. `GhostComputerAgentReachabilityGuardTests` now
asserts the source remains absent and still proves the shipping computer-use
route stays on `ComputerUseBridge`; `ProductionHardeningTests` no longer expects
the deleted file to be present as an App Store-excluded wrapper. Reintroducing a
GhostComputerAgent-style path requires a new provenance deliberation first.

PR47 OAuth token refresh AgentEvent provenance is also closed.
`CloudProviderAuthService` now records `auth.token.refreshed`
requested/completed/failed events around silent expired/expiring OAuth refresh.
The persisted payload is bounded to provider, auth mode, old-token SHA-256
fingerprint prefix, expiry timestamps, refresh-token rotation boolean, scalar
duration, and sanitized failure class. `CloudProviderAuthServiceRefreshAgentEventTests`
prove access tokens, refresh tokens, client secrets, raw provider responses, and
raw provider error payloads are not stored in AgentEvents. This is audit
visibility only; it adds no Touch ID prompt and no Sovereign route for silent
background refresh.

PR49 AgentGraphMemory recordExecution dead-code deletion is also closed.
Claude's detective resolutions found `AgentGraphMemory.recordExecution` had no
production callers, so the unreachable graph write path was deleted instead of
instrumented. `AgentGraphMemoryDeadCodeGuardTests` asserts the writer method,
session counters, source/tag helper methods, and truncation helper stay absent
while the live recall/source/context/distillation APIs remain. Reintroducing an
agent graph write path requires a new provenance deliberation first.

PR50 Credential UserDefaults absence guard is also closed.
`CredentialUserDefaultsAbsenceGuardTests` source-scans production Swift for
`UserDefaults` or `@AppStorage` lines carrying credential-shaped markers and
keeps API keys, OAuth access/refresh tokens, client secrets, passwords,
credentials, and bearer tokens out of defaults-backed storage. It also locks
`Epistemos/Engine/Keychain.swift` to Security.framework primitives with no
`UserDefaults` fallback. This is test-only; no credential flow, OAuth behavior,
Sovereign route, Core/MAS policy, MCP/Hermes route, or production source
changed.

PR51 CloudProviderSetupCard source guard is also closed.
`CloudProviderSetupCardSourceGuardTests` asserts the OAuth setup card does not
own `LAContext`, does not evaluate biometric policy, delegates account sign-in
through `InferenceState`, does not directly construct or store
`CloudProviderOAuthCredential`, carries no raw access/refresh-token markers,
and keeps Google OAuth client config secrets Keychain-backed while defaults
only store filename/project-ID metadata. This is test-only; no credential flow,
OAuth behavior, Sovereign route, Core/MAS policy, MCP/Hermes route, or
production source changed.

PR52 startup credential import AgentEvent provenance is also closed.
`StartupAutoDiscovery.perform` now emits sanitized `auth.credential.imported`
completed events through an injected `AgentToolProvenanceSyncRecorder` only
after a successful Keychain save from environment or config-file discovery.
The event payload is bounded to env var, keychain key, credential source, and
config filename provenance; `StartupAutoDiscoveryCredentialImportedAgentEventTests`
prove raw credential values are never persisted, existing Keychain credentials
do not become false imports, and failed Keychain saves do not emit import rows.
This is audit visibility only; no Touch ID prompt, Sovereign route, credential
flow behavior, Core/MAS policy, MCP/Hermes route, or production source beyond
startup provenance changed.

PR53 ShadowGitCheckpoint dead-code deletion is also closed. Claude's detective
resolutions found `ShadowGitCheckpoint.checkpoint/rollback` had no production
callers, so `Epistemos/Omega/Safety/ShadowGitCheckpoint.swift` was deleted
instead of instrumented or wired. `RuntimeValidationTests` now treats the
surface as intentionally absent, and `ShadowGitCheckpointDeadCodeGuardTests`
asserts production Swift no longer references `ShadowGitCheckpoint` or
`shadow_git`. Reintroducing a shadow-git checkpoint/rollback path requires a
fresh provenance, Core/MAS, and subprocess deliberation gate.

PR54 VisualVerifyLoop bootstrap dead-code cleanup is also closed. Claude's
detective resolutions found no production caller for `VisualVerifyLoop.verify`,
so `AppBootstrap` no longer owns the unwired singleton and `AppEnvironment`
no longer injects it. `VisualVerifyLoop.swift` stays as a tested helper, while
`VisualVerifyLoopBootstrapDeadCodeGuardTests` guards the absence of bootstrap,
environment, and `ComputerUseBridge` visual-verification claims until a future
bridge slice deliberately wires post-action verification.

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
- `docs/fusion/deliberation/reasoning_loop_agent_event_pr7_deliberation_2026_05_02.md`
- `Epistemos/Omega/Inference/ReasoningLoopService.swift` only for PR7 evidence
  or a future ReasoningLoop regression fix gate.
- `docs/fusion/deliberation/cloud_llm_agent_event_pr8_deliberation_2026_05_02.md`
- `Epistemos/Engine/LLMService.swift` only for PR8 CloudLLM generate evidence
  or PR9 CloudLLM stream evidence or PR10 CloudLLM structured-output evidence
  or a future CloudLLM provenance regression fix gate.
- `docs/fusion/deliberation/cloud_llm_stream_agent_event_pr9_deliberation_2026_05_02.md`
- `docs/fusion/deliberation/cloud_llm_structured_agent_event_pr10_deliberation_2026_05_02.md`
- `docs/fusion/deliberation/local_agent_loop_agent_event_pr11_deliberation_2026_05_02.md`
- `Epistemos/LocalAgent/LocalAgentLoop.swift` only for PR11 LocalAgentLoop
  evidence or a future LocalAgentLoop provenance regression fix gate.
- `docs/fusion/deliberation/driver_channel_agent_event_pr12_deliberation_2026_05_02.md`
- `Epistemos/Omega/iMessageDriver/IMessageDriverService.swift` only for PR12
  DriverChannelToolExecutor evidence or a future driver-channel provenance
  regression fix gate.
- `docs/fusion/deliberation/relay_channel_agent_event_pr13_deliberation_2026_05_02.md`
- `Epistemos/Omega/Channels/DriverChannelControlPlane.swift` only for PR13
  remote relay channel evidence or a future remote-relay provenance regression
  fix gate.
- `docs/fusion/deliberation/agent_grep_agent_event_pr14_deliberation_2026_05_02.md`
- `Epistemos/KnowledgeFusion/AgentGrepService.swift` only for PR14 AgentGrep
  evidence or a future AgentGrep provenance regression fix gate.
- `docs/fusion/deliberation/agent_query_engine_agent_event_pr15_deliberation_2026_05_02.md`
- `Epistemos/Engine/AgentHarness/AgentQueryEngine.swift` only for PR15
  AgentQueryEngine backend-stream evidence or a future AgentQueryEngine
  provenance regression fix gate.
- `docs/fusion/deliberation/instant_recall_agent_event_pr16_deliberation_2026_05_02.md`
- `docs/fusion/deliberation/instant_recall_async_agent_event_pr17_deliberation_2026_05_02.md`
- `Epistemos/KnowledgeFusion/InstantRecallService.swift` only for PR16
  InstantRecall sync recall evidence, PR17 InstantRecall async recall evidence,
  or a future InstantRecall provenance regression fix gate.

Allowed write set:
- PR1 persistence-only: already closed.
- PR2 PipelineService observed tool instrumentation: already closed.
- PR3 ChatCoordinator/Rust-stream instrumentation: already closed.
- PR4 HookRegistry API-level lifecycle instrumentation: already closed.
- PR5 read-only Settings visibility: already closed.
- PR6 PipelineService HookRegistry production mount: already closed for the
  local tool-loop only.
- PR7 Omega ReasoningLoop internal tool-call provenance: already closed for
  existing reasoning-loop internal search calls only.
- PR8 CloudLLM non-streaming cloud generation provenance: already closed for
  `CloudLLMClient.generate(...)` only.
- PR9 CloudLLM direct cloud streaming provenance: already closed for
  `CloudLLMClient.stream(...)` only.
- PR10 CloudLLM provider-native structured-output provenance: already closed
  for `CloudLLMClient.generateStructured(...)` only.
- PR11 LocalAgentLoop tool execution provenance: already closed for parsed
  `LocalAgentLoop` tool calls only.
- PR12 DriverChannelToolExecutor channel provenance: already closed for
  `DriverChannelToolExecutor.execute(...)` only.
- PR13 remote relay channel provenance: already closed for
  `RemoteRelayChannelAdapter` relay send/fetch/list/audit HTTP calls only.
- PR14 AgentGrep search provenance: already closed for
  `AgentGrepService.search(query:kindFilter:limit:)` only.
- PR15 AgentQueryEngine backend-stream provenance: already closed for backend
  `.toolUse` / `.toolResult` events emitted by `AgentQueryEngine.runTurn(...)`
  only.
- PR16 InstantRecall sync recall provenance: already closed for
  `InstantRecallService.search(queryText:topK:)` only.
- PR17 InstantRecall async recall provenance: already closed for
  `InstantRecallService.searchAsync(query:topK:)` only.
- PR18 ShadowSearch backend provenance: already closed for
  `ShadowSearchService.search(text:domain:limit:)` only.
- PR19 SearchIndex fused async provenance: already closed for
  `SearchIndexService.fusedSearchAsync(query:weights:now:)` only.
- PR0 sync recorder enabler: already closed for shared sync factory/recorder
  reuse only.
- PR20 SearchIndex fused sync provenance: already closed for
  `SearchIndexService.fusedSearch(query:weights:now:)` only.
- PR21 SearchIndex direct page sync/async provenance: already closed for
  `search(query:limit:)` and `searchAsync(query:limit:)` only.
- PR22 SearchIndex block sync/async provenance: already closed for
  `searchBlocks(query:limit:)` and `searchBlocksAsync(query:limit:)` only.
- PR23 MLX image generation attempt provenance: already closed for
  `MLXImageGenerationService.generate(prompt:aspectRatio:)` only.
- PR24 LocalGGUF non-streaming generate provenance: already closed for
  `LocalGGUFClient.generate(...)` only.
- PR25 LocalBackend stream provenance: already closed for
  `LocalBackendLLMClient.stream(...)` only.
- PR26 local runtime recorder mount: already closed for the `AppBootstrap`
  recorder injection into `LocalGGUFClient` and `LocalBackendLLMClient` only.
- PR27 LocalMLX direct generate provenance: already closed for
  `LocalMLXClient.generate(...)` only.
- PR28 LocalMLX direct stream provenance: already closed for
  `LocalMLXClient.stream(...)` only.
- PR29 LocalBackend direct generate provenance: already closed for
  `LocalBackendLLMClient.generate(...)` only.
- PR32 LocalGGUF direct stream provenance: already closed for
  `LocalGGUFClient.stream(...)` only.
- PR33 Apple Intelligence direct generate provenance: already closed for
  `AppleIntelligenceService.generate(...)` only.
- PR34 AgentEvent v1.6 forward vocabulary: already closed for
  `AgentProvenanceEventKind` raw-value compatibility and EventStore
  persistence tests only.
- PR35 MCPBridge Core `tools/call` denial provenance: already closed for
  requested/denied policy-gate audit rows only.
- PR36 Phase7 NightBrain trigger provenance: already closed for
  `Phase7Bridge.triggerNightbrainJob(jobType:priority:)` only.
- PR37 Phase5 SSM state provenance: already closed for
  `Phase5Bridge.manageSsmState(actionJson:)` only.
- PR39 ComputerUseBridge provenance: already closed for
  `ComputerUseBridge.execute(actionJSON:)` only.
- PR40 Phase4 perceive provenance: already closed for
  `Phase4Bridge.perceive(appName:depth:)` only.
- PR41 Phase4 interact provenance: already closed for
  `Phase4Bridge.interact(actionJson:)` only.
- PR42 Phase4 screen_watch provenance: already closed for
  `Phase4Bridge.startScreenWatch(watchJson:)` only.
- PR43 ClarifyPromptBridge provenance: already closed for
  `ClarifyPromptBridge.ask(questionJson:)` only.
- PR44 Bridge no-double-count source guard: already closed for the four
  intentional no-instrument Bridge surfaces only.
- PR45 GhostComputerAgent reachability guard: already closed for the no-route
  source guard only; if production routing starts using `GhostComputerAgent`,
  open a fresh provenance slice before enabling that path.
- PR47 OAuth token refresh AgentEvent provenance: already closed for silent
  expired/expiring credential refresh only.
- PR54 VisualVerifyLoop bootstrap dead-code cleanup: already closed for the
  unwired `AppBootstrap`/`AppEnvironment` ownership surface only; future
  post-action visual verification must open a fresh ComputerUse/Omega
  provenance and Core/MAS gate before wiring `VisualVerifyLoop.verify`.
- Future CloudLLM paths beyond generate/stream/structured output,
  ChatCoordinator paths beyond PR3, LocalAgentLoop paths beyond parsed tool
  execution, driver-channel paths beyond the executor wrapper and remote relay
  HTTP client, AgentQueryEngine paths beyond backend tool stream events,
  InstantRecall paths beyond sync/async recall search, Omega paths beyond
  ReasoningLoop internal search, or broader runtime
  instrumentation only after a new deliberation gate names exact runtime files
  and focused tests.
- Docs under `docs/fusion/**`.

Forbidden write set:
- Future production chat, Omega beyond ReasoningLoop internal search, hooks,
  approvals, or tool execution without a fresh live-emission gate.
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
- PR6 red log:
  `/tmp/epistemos-agent-event-hook-mount-pr6-red-20260502.log`.
- PR6 green log:
  `/tmp/epistemos-agent-event-hook-mount-pr6-green-20260502.log`.
  The focused Swift Testing suite passed 2 tests; Xcode still printed known
  SwiftLint package-plugin noise after `TEST SUCCEEDED`.
- PR7 red guard:
  `/tmp/epistemos-reasoning-loop-agent-event-pr7-red-guard-20260502.log`.
- PR7 green log:
  `/tmp/epistemos-reasoning-loop-agent-event-pr7-green-20260502.log`.
  The focused behavior test passed; Xcode still printed known SwiftLint
  package-plugin noise after `TEST SUCCEEDED`.
- PR8 red log:
  `/tmp/epistemos-cloud-llm-agent-event-pr8-red-20260502.log`.
- PR8 green log:
  `/tmp/epistemos-cloud-llm-agent-event-pr8-green-20260502.log`.
  The focused behavior tests passed; Xcode still printed known SwiftLint
  package-plugin noise after `TEST SUCCEEDED`.
- PR9 red log:
  `/tmp/epistemos-cloud-llm-stream-agent-event-pr9-red-20260502.log`.
- PR9 green log:
  `/tmp/epistemos-cloud-llm-stream-agent-event-pr9-green-20260502.log`.
  The focused behavior tests passed; Xcode still printed known SwiftLint
  package-plugin noise after `TEST SUCCEEDED`.
- PR10 red log:
  `/tmp/epistemos-cloud-llm-structured-agent-event-pr10-red-20260502.log`.
- PR10 green log:
  `/tmp/epistemos-cloud-llm-structured-agent-event-pr10-green-20260502.log`.
  The focused behavior tests passed; Xcode still printed known SwiftLint
  package-plugin noise after `TEST SUCCEEDED`.
- PR11 red log:
  `/tmp/epistemos-local-agent-agent-event-pr11-red-20260502.log`.
- PR11 green log:
  `/tmp/epistemos-local-agent-agent-event-pr11-green-20260502.log`.
  The focused `LocalAgentLoopTests` suite passed 36 tests; Xcode still printed
  known SwiftLint package-plugin noise after `TEST SUCCEEDED`.
- PR12 red log:
  `/tmp/epistemos-driver-channel-agent-event-pr12-red-20260502.log`.
- PR12 green log:
  `/tmp/epistemos-driver-channel-agent-event-pr12-green-20260502.log`.
  The focused `ControlPlaneSurfaceTests` suite passed 20 tests; Xcode still
  printed known SwiftLint package-plugin noise after `TEST SUCCEEDED`.
- PR13 first red log:
  `/tmp/epistemos-relay-channel-agent-event-pr13-red-20260502.log`.
- PR13 HTTP-body red log:
  `/tmp/epistemos-relay-channel-agent-event-pr13-http-red-20260502.log`.
- PR13 green log:
  `/tmp/epistemos-relay-channel-agent-event-pr13-green-20260502.log`.
  The focused `ControlPlaneSurfaceTests` suite passed 23 tests; Xcode still
  printed known SwiftLint package-plugin noise after `TEST SUCCEEDED`.
- PR14 red log:
  `/tmp/epistemos-agent-grep-agent-event-pr14-red-20260502.log`.
- PR14 green log:
  `/tmp/epistemos-agent-grep-agent-event-pr14-green-20260502.log`.
  The focused `AgentGrepService (Wave 9.9 base)` Swift Testing suite passed
  10 tests; Xcode still printed known SwiftLint package-plugin noise after
  `TEST SUCCEEDED`.
- PR15 red log:
  `/tmp/epistemos-agent-query-engine-agent-event-pr15-red-20260502.log`.
- PR15 green log:
  `/tmp/epistemos-agent-query-engine-agent-event-pr15-green-20260502.log`.
  The focused `AgentQueryEngine AgentEvent provenance` Swift Testing suite
  passed 2 tests; Xcode still printed known SwiftLint package-plugin noise after
  `TEST SUCCEEDED`.
- PR16 red log:
  `/tmp/epistemos-instant-recall-agent-event-pr16-red-20260502.log`.
- PR16 green log:
  `/tmp/epistemos-instant-recall-agent-event-pr16-green-20260502.log`.
  The focused `InstantRecall - Service` Swift Testing suite passed 20 tests;
  Xcode still printed known SwiftLint package-plugin noise after
  `TEST SUCCEEDED`.
- PR17 red log:
  `/tmp/epistemos-instant-recall-async-agent-event-pr17-red-20260502.log`.
- PR17 green log:
  `/tmp/epistemos-instant-recall-async-agent-event-pr17-green-20260502.log`.
  The focused `InstantRecall - Service` Swift Testing suite passed 25 tests;
  Xcode still printed known SwiftLint package-plugin noise after
  `TEST SUCCEEDED`.
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
- PR6 wired/reachable/visible: PipelineService's local tool-loop path mounts
  `HookRegistry.shared.fireBeforePromptBuild`,
  `HookRegistry.shared.fireBeforeToolCall`, and
  `HookRegistry.shared.fireAfterToolCall`; source guards prove the mount stays
  out of ChatCoordinator and Omega, and the implementation avoids graph,
  editor, Rust, generated-binding, approval-policy, UI, and provider-route
  changes.
- PR7 wired/reachable/visible: ReasoningLoop emits requested, started, and
  completed/failed AgentEvents for parsed internal tool calls with non-empty
  run id, tool call id, actor, metadata, and bounded JSON result payload.
  Source and behavior stay away from HookRegistry, approvals, ChatCoordinator,
  PipelineService, graph, Rust, generated bindings, UI, and EventStore schema.
- PR8 wired/reachable/visible: CloudLLM non-streaming `generate(...)` emits
  requested, started, and completed/failed AgentEvents with non-empty run id,
  tool call id, actor, Hermes route metadata, and sanitized JSON payloads that
  exclude prompts, system prompts, credentials, request bodies, URLs, and model
  output text. Source and behavior stay away from provider routing, streaming,
  structured-output native paths, Hermes subprocesses, MCP, CLI, approvals,
  ChatCoordinator, PipelineService, Omega, graph, Rust, generated bindings, UI,
  and EventStore schema.
- PR9 wired/reachable/visible: CloudLLM direct `stream(...)` emits requested,
  started, and completed/failed AgentEvents with non-empty run id, tool call
  id, actor, Hermes route metadata, and sanitized JSON payloads that exclude
  prompts, system prompts, credentials, request bodies, URLs, and streamed model
  text. Source and behavior stay away from provider routing, SSE parsing,
  reasoning/usage sinks, structured-output native paths, Hermes subprocesses,
  MCP, CLI, approvals, ChatCoordinator, PipelineService, Omega, graph, Rust,
  generated bindings, UI, and EventStore schema.
- PR10 wired/reachable/visible: CloudLLM
  `generateStructured(...)` emits requested, started, and completed/failed
  AgentEvents with non-empty run id, tool call id, actor, Hermes route metadata,
  schema-name metadata, and sanitized JSON payloads that exclude prompts,
  system prompts, credentials, schema bodies, request bodies, URLs, and raw
  structured JSON contents. Source and behavior stay away from provider
  routing, schema request construction, fallback prompt behavior, Hermes
  subprocesses, MCP, CLI, approvals, ChatCoordinator, PipelineService, Omega,
  graph, Rust, generated bindings, UI, and EventStore schema.
- PR11 wired/reachable/visible: LocalAgentLoop parsed tool calls emit
  requested, started, and completed/failed AgentEvents with non-empty run id,
  tool call id, actor, source/surface metadata, bounded result payloads, and
  bounded failure payloads. Source and behavior stay away from model routing,
  tool parsing, tool execution semantics, repair semantics, approvals, UI,
  provider calls, HookRegistry, PipelineService, ChatCoordinator, Omega, graph,
  Rust, generated bindings, and EventStore schema.
- PR12 wired/reachable/visible: DriverChannelToolExecutor emits requested,
  started, and completed/failed AgentEvents around channel-driver tool wrapper
  execution with non-empty run id, tool call id, actor,
  source/surface/channel/tier metadata, bounded result payloads, and bounded
  failure payloads. Source and behavior stay away from channel adapter payload
  construction, contact routing fallback, LocalAgentLoop, PipelineService,
  ChatCoordinator, Omega reasoning, graph, Rust, generated bindings, approval,
  UI, provider routing, and EventStore schema.
- PR13 wired/reachable/visible: RemoteRelayChannelAdapter emits requested,
  started, and completed/failed AgentEvents around relay send/fetch/list/audit
  HTTP calls with non-empty run id, tool call id, actor, route/method metadata,
  bounded result/error payloads, and privacy-preserving argument/result JSON.
  Tests prove message text, relay endpoint host, relay credential, sender
  identity value, relay response body text, and HTTP error body text are not
  persisted in provenance. Source and behavior stay away from channel parser
  semantics, native fallback, DriverChannelToolExecutor, LocalAgentLoop,
  PipelineService, ChatCoordinator, Omega reasoning, graph, Rust, generated
  bindings, approval, UI, provider routing, and EventStore schema.
- PR14 wired/reachable/visible: AgentGrepService emits requested, started, and
  completed/failed AgentEvents around `search(...)` with non-empty run id, tool
  call id, actor, kind-filter/limit metadata, hit-count result payload, and
  backend failure class. Tests prove query text, snippets, vault paths, source
  text, sidecar provenance ids, and tool-use ids are not persisted in AgentEvent
  arguments/results. Source and behavior stay away from indexing algorithm
  changes, unindexing, UI, approvals, provider routing, PipelineService,
  ChatCoordinator, LocalAgentLoop, LLMService, Omega, graph, Rust, generated
  bindings, and EventStore schema.
- PR15 wired/reachable/visible: AgentQueryEngine emits requested, started, and
  completed/failed AgentEvents around backend `.toolUse` / `.toolResult` stream
  events with non-empty run id, tool call id, actor, backend/model/turn/tool
  metadata, output byte count, and error flag. Tests prove prompts, history,
  system prompts, cwd, backend tool input, backend tool output, raw text,
  thinking text, and session ids are not persisted in AgentEvent
  arguments/results. Source and behavior stay away from backend streaming
  semantics, prompt construction, UI, approvals, provider routing,
  ChatCoordinator, PipelineService, LocalAgentLoop, LLMService, Omega, graph,
  Rust, generated bindings, and EventStore schema.
- PR16 wired/reachable/visible: InstantRecall sync search emits requested,
  started, and completed/failed AgentEvents for valid
  `search(queryText:topK:)` calls with non-empty run id, tool call id, actor,
  source/surface metadata, query-count metadata, hit/document counts, elapsed
  milliseconds, and bounded failure classes. Tests prove query text, note ids,
  note bodies, result text, and invalid inputs are not persisted in AgentEvent
  arguments/results. Source and behavior stay away from async recall,
  ShadowSearch, Halo, editor, graph, UI, approvals, provider routing,
  ChatCoordinator, PipelineService, LocalAgentLoop, LLMService, Omega, Rust,
  generated bindings, and EventStore schema.
- PR17 wired/reachable/visible: InstantRecall async search emits requested,
  started, and completed/failed AgentEvents for valid
  `searchAsync(query:topK:)` calls with non-empty async run id, independent async
  tool call id, actor, source/surface metadata, query-count metadata,
  hit/document counts, FFI-only elapsed milliseconds, cancellation terminal
  events, zero-hit completed events, and bounded failure classes. Tests prove
  query text, note ids, note bodies, result text, snippets, scores, embeddings,
  invalid inputs, and localized error descriptions are not persisted in
  AgentEvent arguments/results/errors. Source and behavior stay away from sync
  search metrics, ShadowSearch, Halo, editor, graph, UI, approvals, provider
  routing, ChatCoordinator, PipelineService, LocalAgentLoop, LLMService, Omega,
  Rust, generated bindings, and EventStore schema.
- PR18 wired/reachable/visible: ShadowSearch backend search emits requested,
  started, and completed/failed AgentEvents for valid
  `search(text:domain:limit:)` calls with non-empty run id, per-instance tool
  call id, actor, source/surface metadata, domain/limit/query-count metadata, hit
  count, elapsed milliseconds, zero-hit completed events, cancellation terminal
  events, and bounded ShadowFFI failure classes. Tests prove query text, hit ids,
  titles, snippets, scores, source labels, document bodies, vault paths, raw FFI
  payloads, invalid inputs, localized descriptions, and arbitrary error text are
  not persisted in AgentEvent arguments/results/errors. Source and behavior stay
  away from `searchOrThrow`, `stats`, Halo, ContextualShadowsState, UI, graph,
  Rust, generated bindings, and EventStore schema.
- PR19 wired/reachable/visible: SearchIndex fused async search emits requested,
  started, and completed/failed AgentEvents for valid non-empty
  `fusedSearchAsync(query:weights:now:)` calls with non-empty run id,
  per-instance tool call id, actor, source/surface metadata, query character
  count, term count, `weights_profile`, now timestamp, hit count, elapsed
  milliseconds, zero-hit completed events, cancellation terminal events, and
  bounded `cancelled|sql_error|unknown_error` failure classes. Tests prove the
  source surface excludes sync `fusedSearch` instrumentation and forbidden
  recorder fire-and-forget patterns; the FTS5-gated runtime assertions are
  present but skipped on hosts where the suite's existing FTS5 probe is false.
- PR0 sync recorder enabler wired/reachable/visible: the shared
  `AgentToolProvenanceEventFactory` feeds both the existing main-actor recorder
  and the new nonisolated `AgentToolProvenanceSyncRecorder`. Focused tests prove
  ordered sync lifecycle events, EventStore schema compatibility, incomplete
  identity refusal, and source guards for forbidden bridge patterns while sync
  `SearchIndexService.fusedSearch(...)` remains direct until PR20.
  Source and behavior stay away from RRF SQL, VaultSyncService, UI, graph, Rust,
  generated bindings, and EventStore schema.
- PR20 wired/reachable/visible: SearchIndex fused sync search emits requested,
  started, and completed/failed AgentEvents for valid non-empty
  `fusedSearch(query:weights:now:)` calls with non-empty run id, per-instance
  tool call id, actor, source/surface metadata, query character count, term
  count, `weights_profile`, now timestamp, hit count, elapsed milliseconds,
  zero-hit completed events, and bounded `cancelled|sql_error|unknown_error`
  failure classes. Tests prove the sync source surface uses the sync recorder
  without `Task`, `Task.detached`, `DispatchQueue.main.sync`, or
  `MainActor.assumeIsolated`; the FTS5-gated runtime assertions are present but
  skipped on hosts where the suite's existing FTS5 probe is false.
- PR21 wired/reachable/visible: SearchIndex direct page sync and async search
  emits requested, started, and completed/failed AgentEvents for valid non-empty
  `search(query:limit:)` and `searchAsync(query:limit:)` calls with non-empty
  run id, per-instance tool call id, actor, source/surface metadata, query
  character count, term count, limit, hit count, elapsed milliseconds, zero-hit
  completed events, and bounded `cancelled|sql_error|unknown_error` failure
  classes. Tests prove direct sync uses the sync recorder without `Task`,
  `Task.detached`, `DispatchQueue.main.sync`, or `MainActor.assumeIsolated`,
  and that block-search tool names stay absent from the direct page slice; the
  FTS5-gated runtime assertions are present but skipped on hosts where the
  suite's existing FTS5 probe is false.
- PR22 wired/reachable/visible: SearchIndex block sync and async search emits
  requested, started, and completed/failed AgentEvents for valid non-empty
  `searchBlocks(query:limit:)` and `searchBlocksAsync(query:limit:)` calls with
  non-empty run id, per-instance tool call id, actor, source/surface metadata,
  query character count, term count, limit, hit count, elapsed milliseconds,
  zero-hit completed events, and bounded `cancelled|sql_error|unknown_error`
  failure classes. Tests prove block sync uses the sync recorder without
  `Task`, `Task.detached`, `DispatchQueue.main.sync`, or
  `MainActor.assumeIsolated`, and that direct-page/fused tool names stay absent
  from the block-search slice; the FTS5-gated runtime assertions are present
  but skipped on hosts where the suite's existing FTS5 probe is false.
- PR23 wired/reachable/visible: MLX image generation emits requested, started,
  and completed/failed AgentEvents around the existing
  `generate(prompt:aspectRatio:)` scaffold with non-empty run id, per-service
  tool call id, actor, source/surface/provider metadata, prompt character count,
  aspect ratio, elapsed milliseconds, success boolean, and bounded
  `flux_pipeline_unavailable|unknown_error` failure classes. Tests prove prompt
  text, image path, model id, FAL hints, localized descriptions, arbitrary error
  text, cloud routing, and filesystem paths are not persisted in AgentEvent
  arguments/results/errors.
- PR24 wired/reachable/visible: LocalGGUF non-streaming generation emits
  requested, started, and completed/failed AgentEvents around
  `LocalGGUFClient.generate(...)` with non-empty run id, per-client tool call id,
  actor, source/surface/provider metadata, requested/resolved runtime, reasoning
  mode, max token count, prompt/system prompt character counts, steering-hints
  presence, elapsed milliseconds, output character count, success boolean, and
  bounded `backend_failure` terminal failure class. Tests prove prompt text,
  system prompts, steering hint JSON, generated output, model id, artifact id,
  filesystem paths, localized descriptions, and arbitrary error text are not
  persisted in AgentEvent arguments/results/errors.
- PR25 wired/reachable/visible: LocalBackend stream routing emits requested,
  started, and completed/failed AgentEvents around
  `LocalBackendLLMClient.stream(...)` with non-empty run id, per-router tool call
  id, actor, source/surface/provider metadata, requested/resolved runtime,
  reasoning mode, max token count, prompt/system prompt character counts,
  steering-hints presence, elapsed milliseconds, chunk count, output character
  count, success boolean, and bounded
  `cancelled|model_required|runtime_unavailable|model_unavailable|backend_failure`
  failure classes. Tests prove prompt text, system prompts, steering hint JSON,
  streamed output, model id, artifact id, filesystem paths, localized
  descriptions, arbitrary error text, Hermes/MCP/subprocess surfaces,
  browser/computer-use surfaces, LocalAuthentication, and ANE/private API
  details are not persisted in AgentEvent arguments/results/errors.
- PR26 wired/reachable/visible: `AppBootstrap` live-mounts one shared
  `AgentToolProvenanceRecorder` into `LocalGGUFClient` and
  `LocalBackendLLMClient`, so the already-closed PR24 GGUF generate and PR25
  LocalBackend stream instrumentation are reachable from normal app boot.
  Source guards prove this mount does not create a second recorder per client
  and does not add routing, EventStore schema, UI, graph, Rust, generated
  binding, Hermes/MCP, Sovereign, or ANE/private API work.
- PR27 wired/reachable/visible: Direct `LocalMLXClient.generate(...)` emits
  requested, started, and completed/failed AgentEvents with non-empty run id,
  per-client tool call id, actor, source/surface/provider metadata,
  requested/resolved runtime, reasoning mode, max token count, prompt/system
  prompt character counts, steering-hints presence, elapsed milliseconds, output
  character count, success boolean, and bounded control-plane/backend failure
  classes. Tests prove prompt text, system prompts, steering hint JSON,
  generated output, model id, artifact id, image URLs, filesystem paths,
  localized descriptions, arbitrary error text, Hermes/MCP/subprocess surfaces,
  browser/computer-use surfaces, LocalAuthentication, and ANE/private API
  details are not persisted in AgentEvent arguments/results/errors.
- PR28 wired/reachable/visible: Direct `LocalMLXClient.stream(...)` emits
  requested, started, and completed/failed/cancelled AgentEvents with non-empty
  run id, per-client tool call id, actor, source/surface/provider metadata,
  requested/resolved runtime, reasoning mode, max token count, prompt/system
  prompt character counts, steering-hints presence, elapsed milliseconds, output
  character count, streamed chunk count, success boolean, and bounded
  control-plane/backend/cancelled failure classes. Tests prove prompt text,
  system prompts, steering hint JSON, streamed output, model id, artifact id,
  image URLs, filesystem paths, localized descriptions, arbitrary error text,
  Hermes/MCP/subprocess surfaces, browser/computer-use surfaces,
  LocalAuthentication, and ANE/private API details are not persisted in
  AgentEvent arguments/results/errors.
- PR29 wired/reachable/visible: `LocalBackendLLMClient.generate(...)` emits
  requested, started, and completed/failed AgentEvents with non-empty run id,
  per-router tool call id, actor, source/surface/provider metadata,
  requested/resolved runtime, reasoning mode, max token count, prompt/system
  prompt character counts, steering-hints presence, elapsed milliseconds, output
  character count, success boolean, and bounded
  `cancelled|model_required|runtime_unavailable|model_unavailable|backend_failure`
  failure classes. Tests prove prompt text, system prompts, steering hint JSON,
  generated output, model id, artifact id, filesystem paths, localized
  descriptions, arbitrary error text, Hermes/MCP/subprocess surfaces,
  browser/computer-use surfaces, LocalAuthentication, and ANE/private API
  details are not persisted in AgentEvent arguments/results/errors.
- PR32 wired/reachable/visible: Direct `LocalGGUFClient.stream(...)` emits
  requested, started, and completed/failed AgentEvents with non-empty run id,
  per-client tool call id, actor, source/surface/provider metadata,
  requested/resolved runtime, reasoning mode, max token count, prompt/system
  prompt character counts, steering-hints presence, elapsed milliseconds, chunk
  count, output character count, success boolean, and bounded
  `cancelled|runtime_unavailable|model_not_loaded|model_not_found|backend_failure`
  failure classes. Tests prove prompt text, system prompts, steering hint JSON,
  streamed output, model id, artifact id, filesystem paths, localized
  descriptions, arbitrary error text, Hermes/MCP/subprocess surfaces,
  browser/computer-use surfaces, LocalAuthentication, and ANE/private API
  details are not persisted in AgentEvent arguments/results/errors.
- PR33 wired/reachable/visible: Direct `AppleIntelligenceService.generate(...)`
  emits requested, started, and completed/failed AgentEvents with non-empty run
  id, per-service tool call id, actor, source/surface/provider metadata,
  prompt/system/resolved-system prompt character counts,
  augmented-system-prompt presence, elapsed milliseconds, output character
  count, success boolean, and bounded
  `unavailable|thermal_pause|cancelled|generation_failed` failure classes.
  Tests prove prompt text, system prompts, augmented vault context, generated
  output, localized descriptions, arbitrary backend error text,
  Hermes/MCP/subprocess surfaces, browser/computer-use surfaces,
  LocalAuthentication, and ANE/private API details are not persisted in
  AgentEvent arguments/results/errors.
- PR34 wired/reachable/visible: `AgentProvenanceEventKind` contains the six
  simulation v1.6 forward raw values and EventStore can persist/reload each as
  a tool-less `forward_variant_only` row. No runtime emits these events yet, and
  no dispatch panel, helper summarizer, multi-vault UI, Rust enum, Swift stream
  event, generated binding, or schema surface was changed.

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

PR4 read-only EventStore projection consumer is also closed. EventStore now
exposes `graphEventProjectionSnapshot(limit:)`, which composes the existing
bounded recent-row read with `DurableGraphEventProjection.snapshot(from:)`.
This is a read-only consumer API only: no renderer, retrieval, Halo, Theater,
Rust, OpLog, mutation, repair, polling, or UI side effects.

PR5 read-only Settings projection visibility is also closed. The existing
`GraphEventVisibilityRow` now reads the PR4 consumer API once on appear/refresh
and displays bounded event/node/edge counts without adding timers, `.task`
loops, repair actions, Rust, OpLog, graph renderer, retrieval, Halo, or Theater
side effects.

PR6 read-only audit projection consumer is also closed. `GraphEventAuditProjectionService`
now consumes the existing `EventStore.graphEventProjectionSnapshot(limit:)`
API and returns bounded event/node/edge counts, latest event id, node ids, edge
ids, and generation time for audit consumers without graph renderer, retrieval,
Halo, Theater, OpLog, Rust, generated-binding, EventStore schema, mutation,
repair, polling, timer, or UI side effects.

PR7 read-only Halo projection ribbon is also closed. `HaloController` refreshes
a bounded `GraphEventAuditProjectionReport` through
`GraphEventAuditProjectionService` when the Halo panel opens, and
`ShadowPanelContent` exposes event/node/edge counts in a read-only ribbon
without graph renderer, retrieval, Theater, OpLog, Rust, generated-binding,
EventStore schema, mutation, repair, polling, timer, or projection-worker side
effects.

PR8 read-only Settings audit projection visibility is also closed. The existing
`GraphEventVisibilityRow` refreshes a bounded
`GraphEventAuditProjectionService` report on appear/refresh and displays
event/node/edge/latest-event counts without changing `SettingsView`, graph
renderer, retrieval, Halo, Theater, OpLog, Rust, generated-binding, EventStore
schema, mutation, repair, polling, timer, or projection-worker behavior.

PR9 read-only Trace Inspector projection visibility is also closed.
`TraceInspectorView` displays a compact durable GraphEvent projection summary
backed by `GraphEventAuditProjectionService().auditReport(limit: 100)`. The
refresh path computes the bounded report and trace snapshot off the main actor,
cancels stale refresh tasks, and keeps the projection service explicitly
nonisolated/Sendable without graph renderer, retrieval, Halo, Theater, OpLog,
Rust, generated-binding, EventStore schema, mutation, repair, polling, timer,
or projection-worker behavior.

PR10 read-only QueryRuntime projection hint is also closed. `QueryRuntime`
consumes an injected or env-enabled bounded `DurableGraphProjectionSnapshot`
only as a stable tie-break for existing full-text retrieval candidates. It never
creates new hits, never writes to SearchIndex/EventStore, never touches semantic
retrieval, graph renderer, Theater, OpLog, Rust, generated bindings, mutation,
repair, polling, timer, or projection-worker behavior, and defaults off unless
`EPISTEMOS_GRAPH_EVENT_QUERY_PROJECTION_V1=1`.

PR38 test-only consumer projection guard is also closed. The guard source-reads
the existing EventStore, audit service, Settings, Halo, Trace Inspector, and
QueryRuntime projection consumers and proves they remain bounded, read-only, and
outside graph renderer, retrieval, OpLog, Rust, mutation, repair, polling, timer,
project-file, and production-source changes.

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
- `docs/fusion/deliberation/graph_event_projection_visibility_pr5_deliberation_2026_05_02.md`
- `docs/fusion/deliberation/graph_event_audit_projection_pr6_deliberation_2026_05_02.md`
- `docs/fusion/deliberation/graph_event_halo_projection_pr7_deliberation_2026_05_02.md`
- `docs/fusion/deliberation/graph_event_query_projection_pr10_deliberation_2026_05_02.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `/tmp/epistemos-graph-event-pr1-green-20260501-r1.log`
- `/tmp/epistemos-graph-event-visibility-pr2-final-20260501.log`
- `/tmp/epistemos-graph-event-projection-pr3-green-20260501.log`
- `Epistemos/Models/MutationEnvelope.swift`
- `Epistemos/State/EventStore.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `Epistemos/Views/Settings/GraphEventVisibilityRow.swift`
- `Epistemos/Engine/GraphEventAuditProjectionService.swift`
- `Epistemos/Views/Capture/TraceInspectorView.swift` only for PR9 evidence and
  future Trace Inspector projection-summary regression checks.
- `Epistemos/Engine/QueryRuntime.swift` only for PR10 evidence and future
  retrieval projection-hint regression checks.
- `EpistemosTests/GraphEventConsumerProjectionGuardTests.swift` only for PR38
  source-guard evidence.
- `Epistemos/Engine/HaloController.swift` only for PR7 evidence and future
  Halo projection-ribbon regression checks.
- `Epistemos/Views/Halo/ShadowPanelContent.swift` only for PR7 evidence and
  future Halo projection-ribbon regression checks.
- `Epistemos/Engine/EventDrain.swift` only for the naming collision context.

Allowed write set:
- PR1 durable EventStore mapping: already closed.
- PR2 read-only Settings visibility: already closed.
- PR3 read-only projection snapshots: already closed.
- PR4 read-only EventStore projection consumer: already closed.
- PR5 read-only Settings projection visibility: already closed.
- PR6 read-only audit projection consumer: already closed.
- PR7 read-only Halo projection ribbon: already closed for exactly
  `HaloController` panel-open refresh plus `ShadowPanelContent` read-only
  counts display.
- PR8 read-only Settings audit projection visibility: already closed for
  exactly `GraphEventVisibilityRow` appear/refresh display of the PR6 audit
  report.
- PR9 read-only Trace Inspector projection visibility: already closed for
  exactly `TraceInspectorView` appear/manual-refresh display of the PR6 audit
  report plus cancellation of stale refresh tasks.
- PR10 read-only QueryRuntime projection hint: already closed for exactly
  full-text retrieval stable tie-breaking of existing candidates through an
  injected or env-enabled bounded projection snapshot.
- PR38 test-only consumer projection guard: already closed for exactly
  source-guard coverage of the existing EventStore, audit service, Settings,
  Halo, Trace Inspector, and QueryRuntime projection consumers.
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
- PR4 already supplies the direct EventStore consumer API for a recent
  read-only snapshot. Do not add second wrapper methods, polling, UI, repair,
  renderer, retrieval, Halo, Theater, Rust, or OpLog work without a new gate.

Tests and logs:
- Red log: `/tmp/epistemos-graph-event-pr1-red-20260501.log`.
- Green log: `/tmp/epistemos-graph-event-pr1-green-20260501-r1.log`.
- PR2 final green log:
  `/tmp/epistemos-graph-event-visibility-pr2-final-20260501.log`.
- PR3 red log:
  `/tmp/epistemos-graph-event-projection-pr3-red-20260501.log`.
- PR3 green log:
  `/tmp/epistemos-graph-event-projection-pr3-green-20260501.log`.
- PR4 red log:
  `/tmp/epistemos-graph-event-projection-consumer-pr4-red-20260502.log`.
- PR4 accepted green log:
  `/tmp/epistemos-graph-event-projection-consumer-pr4-green-r2-20260502.log`.
  The first PR4 green command targeted the filename and selected 0 tests, so it
  is not acceptance evidence.
- PR5 red log:
  `/tmp/epistemos-graph-event-projection-visibility-pr5-red-20260502.log`.
- PR5 green log:
  `/tmp/epistemos-graph-event-projection-visibility-pr5-green-20260502.log`.
- PR6 red log:
  `/tmp/epistemos-graph-event-audit-projection-pr6-red-20260502.log`.
- PR6 green log:
  `/tmp/epistemos-graph-event-audit-projection-pr6-green-20260502.log`.
  The focused Swift Testing suite passed 2 tests; Xcode still printed known
  SwiftLint package-plugin noise after `TEST SUCCEEDED`.
- PR7 red log:
  `/tmp/epistemos-graph-event-halo-projection-pr7-red-20260502.log`.
- PR7 green log:
  `/tmp/epistemos-graph-event-halo-projection-pr7-green-20260502.log`.
  The focused HaloController/HaloUI Swift Testing suites passed 40 tests; Xcode
  still printed known SwiftLint package-plugin noise after `TEST SUCCEEDED`.
- PR8 red guard:
  `grep -q 'GraphEventAuditProjectionService' Epistemos/Views/Settings/GraphEventVisibilityRow.swift`
  exited 1 before implementation.
- PR8 source guard:
  `/tmp/epistemos-graph-event-audit-visibility-pr8-source-guard-r2-20260502.log`.
- PR8 build log:
  `/tmp/epistemos-graph-event-audit-visibility-pr8-build-20260502.log`.
  The build exited 0 with `** BUILD SUCCEEDED **`; Xcode still printed known
  SwiftLint package-plugin noise after success.
- PR8 test-bundle compile log:
  `/tmp/epistemos-graph-event-audit-visibility-pr8-build-for-testing-20260502.log`.
  The command exited 0 with `** TEST BUILD SUCCEEDED **`; Xcode still printed
  known SwiftLint package-plugin noise after success.
- PR9 red log:
  `/tmp/epistemos-graph-event-trace-inspector-pr9-red-20260502.log`.
- PR9 green log:
  `/tmp/epistemos-graph-event-trace-inspector-pr9-green-20260502.log`.
  The focused `GraphEventAuditProjectionTests` suite passed 4 tests; Xcode
  still printed known CodeEdit SwiftLint package-plugin footer noise after
  `** TEST SUCCEEDED **`.
- PR10 red log:
  `/tmp/epistemos-graph-event-query-projection-pr10-red-20260502.log`.
- PR10 green log:
  `/tmp/epistemos-graph-event-query-projection-pr10-green-20260502-r2.log`.
  The focused `QueryRuntimeTests` and `GraphEventAuditProjectionTests` suites
  passed 32 tests, including the new GraphEvent projection-hint full-text
  retrieval tests; Xcode still printed known CodeEdit SwiftLint package-plugin
  footer noise after `** TEST SUCCEEDED **`.
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
- PR4 wired/reachable/visible: EventStore returns a bounded read-only
  projection snapshot through `graphEventProjectionSnapshot(limit:)`; the
  focused `EventStoreSchemaTests` suite executed 34 tests including the new
  consumer test.
- PR5 wired/reachable/visible: Settings reads the existing bounded projection
  snapshot consumer and displays read-only event/node/edge counts while the
  focused `OpLogFFIBoundaryGuardTests` source guard proves no mutation, timer,
  repair, Rust, OpLog, graph renderer, retrieval, Halo, or Theater path was
  introduced.
- PR6 wired/reachable/visible: `GraphEventAuditProjectionService` consumes the
  existing EventStore projection snapshot and returns a bounded audit report
  with event/node/edge counts, latest event id, node ids, edge ids, and
  generation time while staying out of graph renderer, retrieval, Halo,
  Theater, OpLog, Rust, generated bindings, EventStore schema, mutation, repair,
  polling, timer, and UI paths.
- PR7 wired/reachable/visible: opening the Halo panel refreshes a bounded
  read-only GraphEvent projection report through `GraphEventAuditProjectionService`,
  and the panel displays event/node/edge counts in a read-only ribbon while
  staying out of graph renderer, retrieval, Theater, OpLog, Rust, generated
  bindings, EventStore schema, mutation, repair, polling, timer, and
  projection-worker paths.
- PR8 wired/reachable/visible: the existing Settings `GraphEventVisibilityRow`
  refreshes a bounded read-only GraphEvent audit projection report through
  `GraphEventAuditProjectionService` and displays event/node/edge/latest-event
  counts while staying out of `SettingsView`, graph renderer, retrieval, Halo,
  Theater, OpLog, Rust, generated bindings, EventStore schema, mutation, repair,
  polling, timer, and projection-worker paths.
- PR9 wired/reachable/visible: the existing Capture Trace Inspector refreshes a
  bounded read-only GraphEvent audit projection report through
  `GraphEventAuditProjectionService` and displays event/node/edge/latest-event
  counts while cancellation guards prevent stale refresh wins and source guards
  keep it out of GraphEvent writes, mutation writes, graph renderer, retrieval,
  Settings, Halo, Theater, OpLog, Rust, generated bindings, EventStore schema,
  repair, polling, timer, and projection-worker paths.
- PR10 wired/reachable/visible: `QueryRuntime` full-text retrieval accepts an
  injected or env-enabled bounded durable GraphEvent projection snapshot and
  applies it only as a stable equal-score tie-break over existing candidates.
  Tests prove projected ghost nodes are not created, the hint is full-text only,
  and the implementation stays out of SearchIndex writes, GraphEvent writes,
  mutation writes, graph renderer, InstantRecall, MeaningAnchor, Theater,
  OpLog, Rust, generated bindings, repair, polling, timer, and
  projection-worker paths.
- PR38 wired/reachable/visible: `GraphEventConsumerProjectionGuardTests`
  source-read EventStore, `GraphEventAuditProjectionService`, Settings, Halo,
  Trace Inspector, and QueryRuntime consumers and prove the existing projection
  paths stay bounded and read-only without production edits.

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
Approval Surface PR3 is also closed. `ApprovalModalView` routes approve-once
through a category-scoped biometric requirement and persistent approval choices
(`Less Interruptions` / `Always Allow`) through device-owner authentication via
the existing shared `SovereignGate`, without touching Rust, Omega,
ChatCoordinator, `AppBootstrap`, `EpistemosApp`, or generated transport.
Rust Matrix PR4 is also closed. `agent_core/src/sovereign/mod.rs` now declares
the Rust-owned action-class matrix seed, doctrine example intents,
`GateRequirement`, `GateOutcome`, category-scoped Sensitive 900-second grace,
Destructive every-time device-owner auth, and a forward Secure-Enclave
key-release requirement for Sovereign-class Pro/Research work. It is additive
and does not wire generated transport, Swift policy, popup migration, Secure
Enclave sealing, tool behavior, UI, Omega, ChatCoordinator, or approval
semantics.
Notes Delete PR5 is also closed. `Epistemos/Views/Notes/NotesSidebar.swift`
now routes the existing permanent page/folder delete destructive alert buttons
through the shared `AppBootstrap` `SovereignGate` with
`.deviceOwnerAuthentication` before delete execution. The pending delete target
is captured before async auth, denied/unavailable auth clears pending state and
does not delete, and the slice does not edit `SovereignGate.swift`, duplicate
`LocalAuthentication`, change planner/delete semantics, migrate any other
confirmation popup, or touch Rust/generated/graph/editor/Omega/ChatCoordinator.
Chat Delete PR6 is also closed. `Epistemos/Views/Chat/ChatSidebarView.swift`
now routes the existing Chat Sidebar context-menu destructive chat delete action
through the shared `AppBootstrap` `SovereignGate` with
`.deviceOwnerAuthentication` before delete execution. Missing/unavailable auth
is denied, the existing `SDChat` deletion/error handling remains unchanged, and
the slice does not edit `SovereignGate.swift`, duplicate `LocalAuthentication`,
migrate note chat, or touch Rust/generated/graph/editor/Omega/ChatCoordinator.
Version Delete PR7 is also closed. `Epistemos/Views/Notes/DiffSheetView.swift`
now routes the existing "Delete This Version" destructive menu action through
the shared `AppBootstrap` `SovereignGate` with `.deviceOwnerAuthentication`
before delete execution. The exact `SDPageVersion` is captured before async
auth so selection changes cannot redirect the delete, denied/unavailable auth
performs no delete, and the existing delete/save/reinsert rollback semantics
remain unchanged. The slice does not edit `SovereignGate.swift`, duplicate
`LocalAuthentication`, migrate other note/editor dialogs, or touch
Rust/generated/graph/Omega/ChatCoordinator.
RootView Destructive PR8 is also closed. `Epistemos/App/RootView.swift` now
routes the existing database error "Reset Database" and vault recovery
"Disconnect Vault" destructive controls through the shared `AppBootstrap`
`SovereignGate` with `.deviceOwnerAuthentication` before calling their original
closures. Red-team P2/P3 findings are addressed: denied reset auth restores the
database recovery alert while the database error remains present, and vault
disconnect has an in-flight auth guard to prevent duplicate prompts/actions.
The slice does not edit `SovereignGate.swift`, duplicate `LocalAuthentication`,
alter database reset or vault recovery semantics, or touch Rust/generated/
graph/Omega/ChatCoordinator.
Model Vault Delete PR9 is also closed. `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift`
now routes the existing Model Vaults sidebar file/folder destructive delete
alert through the shared `AppBootstrap` `SovereignGate` with
`.deviceOwnerAuthentication` before delete execution. The pending delete target
stores a typed file/folder gate target before async auth, denied/unavailable auth
performs no delete, and the slice does not edit `SovereignGate.swift`,
duplicate `LocalAuthentication`, alter model-vault browser/delete semantics, or
touch Rust/generated/graph/Omega/ChatCoordinator.
Custom Tool Delete PR10 is also closed. `Epistemos/Views/Settings/AgentControlSettingsView.swift`
now routes the existing Agent Control custom-tool destructive delete button
through the shared `AppBootstrap` `SovereignGate` with
`.deviceOwnerAuthentication` before calling the original custom-tool manager
delete path. The exact tool name and vault path are captured before async auth,
denied/unavailable auth performs no delete, and the slice does not edit
`SovereignGate.swift`, duplicate `LocalAuthentication`, alter custom-tool
manager semantics, or touch Rust/generated/graph/Omega/ChatCoordinator.
Notes Vault Disconnect PR11 is also closed. `Epistemos/Views/Notes/NotesSidebar.swift`
now routes the normal Notes Sidebar vault menu "Disconnect Vault" destructive
action through the shared `AppBootstrap` `SovereignGate` with
`.deviceOwnerAuthentication` before calling the original
`VaultConnectionActions.disconnect(notesUI:vaultSync:)` helper. The exact vault
URL is captured before async auth and rechecked on the main actor after auth,
missing/unavailable auth performs no disconnect, and an in-flight guard prevents
double prompts/actions. The slice does not edit `SovereignGate.swift`, duplicate
`LocalAuthentication`, alter vault teardown semantics, or touch Rust/generated/
graph/Omega/ChatCoordinator.
Authority Reset PR12 is also closed. `Epistemos/Views/Settings/AuthoritySettingsView.swift`
now routes the existing Authority Settings batch "Reset to defaults" footer and
Quick Setup preset buttons through the shared `AppBootstrap` `SovereignGate`
with `.deviceOwnerAuthentication` before mutating `AgentAuthorityStore`. The
slice denies safely when the shared gate is unavailable, keeps individual
picker changes out of scope, and does not edit `SovereignGate.swift`, duplicate
`LocalAuthentication`, alter authority persistence semantics, or touch
Rust/generated/graph/Omega/ChatCoordinator.
Overseer History Reset PR13 is also closed. `Epistemos/Views/Settings/OverseerSettingsView.swift`
now routes the existing Overseer Settings "Reset history" footer through the
shared `AppBootstrap` `SovereignGate` with `.deviceOwnerAuthentication` before
clearing the read-only route/audit trail. The slice denies safely when the
shared gate is unavailable, leaves programmatic `OverseerAuditState.clear()`
workspace hygiene untouched, and does not edit `SovereignGate.swift`, duplicate
`LocalAuthentication`, alter audit-state semantics, or touch
Rust/generated/graph/Omega/ChatCoordinator.
Settings Reset Everything PR14 is also closed. `Epistemos/Views/Settings/SettingsView.swift`
routes the existing General Settings "Reset Everything" alert through the
shared `AppBootstrap` `SovereignGate` with `.deviceOwnerAuthentication` before
calling `resetAllData()`. The slice preserves the existing first confirmation,
denies safely when the shared gate is unavailable, and does not edit
`SovereignGate.swift`, duplicate `LocalAuthentication`, alter reset semantics,
or touch Rust/generated/graph/Omega/ChatCoordinator.
Settings Workspace Delete PR15 is also closed. `Epistemos/Views/Settings/SettingsView.swift`
routes the existing Saved Workspaces destructive trash button through the shared
`AppBootstrap` `SovereignGate` with `.deviceOwnerAuthentication` before calling
the original workspace delete path. The slice preserves the original
`workspaceService.deleteWorkspace(workspace)` plus `refreshWorkspaces()`
behavior after `.allowed`, denies safely when the shared gate is unavailable,
and does not edit `SovereignGate.swift`, duplicate `LocalAuthentication`, alter
workspace service semantics, or touch Rust/generated/graph/Omega/ChatCoordinator.
Settings Vault Disconnect PR16 is also closed. `Epistemos/Views/Settings/SettingsView.swift`
routes the existing Settings > Vault `Disconnect` destructive button through
the shared `AppBootstrap` `SovereignGate` with `.deviceOwnerAuthentication`
before calling the original vault disconnect helper. The slice denies safely
when the shared gate is unavailable, disables duplicate prompts while auth is
in flight, rechecks that the active vault URL still matches the captured URL
after approval, and does not edit `SovereignGate.swift`, duplicate
`LocalAuthentication`, alter vault disconnect semantics, or touch
Rust/generated/graph/Omega/ChatCoordinator.
Knowledge Fusion Adapter Delete PR17 is also closed.
`Epistemos/KnowledgeFusion/UI/TrainingHistoryView.swift` routes the existing
Training History adapter context-menu `Delete` action through the shared
`AppBootstrap` `SovereignGate` with `.deviceOwnerAuthentication` before calling
the original `KnowledgeFusionViewModel.deleteAdapter(_:)` helper. The slice
denies safely when the shared gate is unavailable, preserves the original
adapter registry/delete semantics after `.allowed`, and does not edit
`SovereignGate.swift`, duplicate `LocalAuthentication`, alter Knowledge Fusion
training history behavior outside the destructive delete action, or touch
Rust/generated/graph/Omega/ChatCoordinator.

Goal:
Route future Core confirmation surfaces through one native macOS biometric gate
without parallel Touch ID prompts or Swift-owned policy matrices.

Authority to read first:
- `docs/fusion/deliberation/sovereign_gate_core_pr1_deliberation_2026_05_02.md`
- `docs/fusion/deliberation/sovereign_gate_approval_surface_pr3_deliberation_2026_05_02.md`
- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §4.2 and Annex B
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `Epistemos/Sovereign/SovereignGate.swift`
- `Epistemos/Views/Approval/ApprovalModalView.swift`
- `EpistemosTests/SovereignGateTests.swift`
- `/tmp/epistemos-sovereign-gate-pr1-red-20260502.log`
- `/tmp/epistemos-sovereign-gate-pr1-green-20260502.log`
- `/tmp/epistemos-sovereign-gate-pr1-green-20260502-r2.log`
- `/tmp/epistemos-sovereign-gate-pr2-red-20260502.log`
- `/tmp/epistemos-sovereign-gate-pr2-green-20260502-r2.log`
- `/tmp/epistemos-sovereign-gate-approval-pr3-red-20260502.log`
- `/tmp/epistemos-sovereign-gate-approval-pr3-green-20260502.log`
- `docs/fusion/deliberation/sovereign_gate_rust_matrix_pr4_deliberation_2026_05_02.md`
- `/tmp/epistemos-sovereign-gate-rust-matrix-pr4-red-20260502.log`
- `/tmp/epistemos-sovereign-gate-rust-matrix-pr4-green-20260502.log`
- `/tmp/epistemos-sovereign-gate-rust-matrix-pr4-green-20260502-r2.log`
- `docs/fusion/deliberation/sovereign_gate_notes_delete_pr5_deliberation_2026_05_02.md`
- `/tmp/epistemos-sovereign-gate-notes-delete-pr5-red-20260502.log`
- `/tmp/epistemos-sovereign-gate-notes-delete-pr5-green-20260502.log`
- `docs/fusion/deliberation/sovereign_gate_chat_delete_pr6_deliberation_2026_05_02.md`
- `/tmp/epistemos-sovereign-gate-chat-delete-pr6-red-20260502.log`
- `/tmp/epistemos-sovereign-gate-chat-delete-pr6-green-20260502.log`
- `docs/fusion/deliberation/sovereign_gate_version_delete_pr7_deliberation_2026_05_02.md`
- `/tmp/epistemos-sovereign-gate-version-delete-pr7-red-20260502.log`
- `/tmp/epistemos-sovereign-gate-version-delete-pr7-green-20260502.log`
- `docs/fusion/deliberation/sovereign_gate_rootview_destructive_pr8_deliberation_2026_05_02.md`
- `/tmp/epistemos-sovereign-gate-rootview-pr8-red-20260502.log`
- `/tmp/epistemos-sovereign-gate-rootview-pr8-green-20260502.log`
- `/tmp/epistemos-sovereign-gate-rootview-pr8-green-r2-20260502.log`
- `docs/fusion/deliberation/sovereign_gate_model_vault_delete_pr9_deliberation_2026_05_02.md`
- `/tmp/epistemos-sovereign-gate-model-vault-pr9-red-20260502.log`
- `/tmp/epistemos-sovereign-gate-model-vault-pr9-green-20260502.log`

Allowed write set:
- PR1 Swift executor and focused tests: already closed.
- PR2 app-owned lifecycle observer and focused tests: already closed.
- PR3 agent approval sheet migration and focused tests: already closed.
- PR4 Rust action-class matrix seed and focused tests: already closed.
- PR5 Notes Sidebar permanent page/folder delete migration and focused tests:
  already closed.
- PR6 Chat Sidebar context-menu destructive chat delete migration and focused
  tests: already closed.
- PR7 DiffSheet version-delete menu migration and focused tests: already
  closed.
- PR8 RootView database reset and vault disconnect migration and focused tests:
  already closed.
- PR9 Model Vaults sidebar file/folder delete migration and focused tests:
  already closed.
- PR10 Agent Control custom-tool delete migration and focused tests: already
  closed.
- PR11 Notes Sidebar vault menu disconnect migration and focused tests: already
  closed.
- PR12 Authority Settings batch reset and Quick Setup preset migration and
  focused tests: already closed.
- PR13 Overseer Settings reset-history footer migration and focused tests:
  already closed.
- PR14 Settings reset-everything alert migration and focused tests: already
  closed.
- PR15 Settings saved-workspace delete migration and focused tests: already
  closed.
- PR16 Settings vault disconnect migration and focused tests: already closed.
- Future generated requirement transport only after a gate names exact Rust,
  Swift, and generated transport boundaries.
- Future lifecycle follow-up only after a gate names exact app lifecycle files
  not already covered by PR2 and proves no unrelated authorization migration.
- Future confirmation-surface migration PRs only after a gate names each exact
  existing surface and its focused tests; Notes Sidebar page/folder permanent
  deletes are already covered by PR5, and Chat Sidebar context-menu chat
  deletes are already covered by PR6, DiffSheet version deletes are already
  covered by PR7, RootView database reset/vault disconnect controls are already
  covered by PR8, Model Vaults sidebar file/folder deletes are already covered
  by PR9, Agent Control custom-tool deletes are already covered by PR10, and
  Notes Sidebar vault menu disconnect is already covered by PR11, and
  Authority Settings batch reset/preset actions are already covered by PR12,
  Overseer Settings reset-history is already covered by PR13, Settings reset
  everything is already covered by PR14, and Settings saved-workspace delete is
  already covered by PR15, and Settings Vault disconnect is already covered by
  PR16.
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
- PR3 red log:
  `/tmp/epistemos-sovereign-gate-approval-pr3-red-20260502.log`.
- PR3 focused green log:
  `/tmp/epistemos-sovereign-gate-approval-pr3-green-20260502.log`.
- PR4 red log:
  `/tmp/epistemos-sovereign-gate-rust-matrix-pr4-red-20260502.log`.
- PR4 focused green log:
  `/tmp/epistemos-sovereign-gate-rust-matrix-pr4-green-20260502.log`.
- PR4 post-rustfmt green log:
  `/tmp/epistemos-sovereign-gate-rust-matrix-pr4-green-20260502-r2.log`.
- PR5 red log:
  `/tmp/epistemos-sovereign-gate-notes-delete-pr5-red-20260502.log`.
- PR5 focused green log:
  `/tmp/epistemos-sovereign-gate-notes-delete-pr5-green-20260502.log`.
- PR6 red log:
  `/tmp/epistemos-sovereign-gate-chat-delete-pr6-red-20260502.log`.
- PR6 focused green log:
  `/tmp/epistemos-sovereign-gate-chat-delete-pr6-green-20260502.log`.
- PR7 red log:
  `/tmp/epistemos-sovereign-gate-version-delete-pr7-red-20260502.log`.
- PR7 focused green log:
  `/tmp/epistemos-sovereign-gate-version-delete-pr7-green-20260502.log`.
- PR7 final focused green log:
  `/tmp/epistemos-sovereign-gate-version-delete-pr7-green-final-20260502.log`.
- PR8 red log:
  `/tmp/epistemos-sovereign-gate-rootview-pr8-red-20260502.log`.
- PR8 focused green log:
  `/tmp/epistemos-sovereign-gate-rootview-pr8-green-20260502.log`.
- PR8 post-red-team focused green log:
  `/tmp/epistemos-sovereign-gate-rootview-pr8-green-r2-20260502.log`.
- PR9 red log:
  `/tmp/epistemos-sovereign-gate-model-vault-pr9-red-20260502.log`.
- PR9 focused green log:
  `/tmp/epistemos-sovereign-gate-model-vault-pr9-green-20260502.log`.
- PR9 final focused green log:
  `/tmp/epistemos-sovereign-gate-model-vault-pr9-green-r2-20260502.log`.
- PR10 red log:
  `/tmp/epistemos-sovereign-gate-custom-tool-pr10-red-20260502.log`.
- PR10 focused green log:
  `/tmp/epistemos-sovereign-gate-custom-tool-pr10-green-r2-20260502.log`.
- PR11 red log:
  `/tmp/epistemos-sovereign-gate-notes-vault-disconnect-pr11-red-20260502.log`.
- PR11 focused green log:
  `/tmp/epistemos-sovereign-gate-notes-vault-disconnect-pr11-green-20260502.log`.
- PR12 red log:
  `/tmp/epistemos-sovereign-gate-authority-reset-pr12-red-20260502.log`.
- PR12 focused green log:
  `/tmp/epistemos-sovereign-gate-authority-reset-pr12-green-20260502.log`.
- PR13 red log:
  `/tmp/epistemos-sovereign-gate-overseer-history-pr13-red-20260502.log`.
- PR13 focused green log:
  `/tmp/epistemos-sovereign-gate-overseer-history-pr13-green-20260502.log`.
- PR14 red log:
  `/tmp/epistemos-sovereign-gate-settings-reset-pr14-red-20260502.log`.
- PR14 focused green log:
  `/tmp/epistemos-sovereign-gate-settings-reset-pr14-green-20260502.log`.
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
- PR3 wired/reachable/visible: the existing agent approval sheet supplies
  Sovereign Gate requirements for approve-once and persistent-approval
  decisions, focused tests prove the mapping, and deny/timeout remain immediate.
- PR3 boundary: no Rust kernels, Omega policy, ChatCoordinator, generated
  bindings, entitlements, protected graph/editor files, subprocesses, solver
  hot paths, tensor copies, or memory hot paths are touched.
- PR4 wired/reachable/visible: Rust exposes the additive
  `agent_core::sovereign` matrix seed, focused Rust tests prove doctrine
  examples, risk-level bridging, Sensitive grace, Destructive no-grace,
  Sovereign forward requirement, and lower-snake-case serialization, and the
  slice stays out of Swift policy, generated transport, popup migration, UI,
  approval semantics, Secure Enclave sealing, graph/editor files, subprocesses,
  solver hot paths, tensor copies, and memory hot paths.
- PR5 wired/reachable/visible: the existing Notes Sidebar permanent page/folder
  delete buttons request shared `SovereignGate` device-owner authentication
  before deletion, focused tests prove both delete surfaces map to Destructive
  auth with explicit reason strings, denied/unavailable auth performs no delete,
  and the slice stays out of `SovereignGate.swift`, duplicate
  `LocalAuthentication`, delete planner semantics, generated transport, Rust,
  graph/editor files, Omega, ChatCoordinator, subprocesses, solver hot paths,
  tensor copies, and memory hot paths.
- PR6 wired/reachable/visible: the existing Chat Sidebar context-menu
  destructive chat delete action requests shared `SovereignGate` device-owner
  authentication before deletion, focused tests prove the delete surface maps to
  Destructive auth with an explicit reason string, denied/unavailable auth
  performs no delete, and the slice stays out of `SovereignGate.swift`,
  duplicate `LocalAuthentication`, chat persistence semantics, generated
  transport, Rust, graph/editor files, Omega, ChatCoordinator, subprocesses,
  solver hot paths, tensor copies, and memory hot paths.
- PR7 wired/reachable/visible: the existing DiffSheet "Delete This Version"
  menu action requests shared `SovereignGate` device-owner authentication before
  deletion, focused tests prove the delete surface maps to Destructive auth with
  an explicit reason string, source guards prove the menu calls the gate path
  instead of direct deletion, the authorized delete uses the captured
  `SDPageVersion` only after `.allowed`, denied/unavailable auth performs no
  delete, and the slice stays out of `SovereignGate.swift`, duplicate
  `LocalAuthentication`, version persistence semantics, generated transport,
  Rust, graph files, Omega, ChatCoordinator, subprocesses, solver hot paths,
  tensor copies, and memory hot paths.
- PR8 wired/reachable/visible: the existing RootView database error "Reset
  Database" and vault recovery "Disconnect Vault" destructive controls request
  shared `SovereignGate` device-owner authentication before calling their
  original closures, focused tests prove both controls map to Destructive auth
  with explicit reason strings, source guards prove direct closure calls moved
  behind the gate, denied reset auth restores the database recovery alert while
  the error remains present, vault disconnect has an in-flight auth guard, and
  the slice stays out of `SovereignGate.swift`, duplicate `LocalAuthentication`,
  database reset/vault recovery semantics, generated transport, Rust, graph
  files, Omega, ChatCoordinator, subprocesses, solver hot paths, tensor copies,
  and memory hot paths.
- PR9 wired/reachable/visible: the existing Model Vaults sidebar file/folder
  delete alert requests shared `SovereignGate` device-owner authentication
  before deleting the captured file or folder target, focused tests prove both
  delete target types map to Destructive auth with explicit reason strings,
  source guards prove the alert calls the authorization path instead of direct
  deletion, the authorized delete runs only after `.allowed`, denied/unavailable
  auth performs no delete, and the slice stays out of `SovereignGate.swift`,
  duplicate `LocalAuthentication`, model-vault browser/delete semantics,
  generated transport, Rust, graph files, Omega, ChatCoordinator, subprocesses,
  solver hot paths, tensor copies, and memory hot paths.
- PR10 wired/reachable/visible: the existing Agent Control custom-tool delete
  button requests shared `SovereignGate` device-owner authentication before
  calling the custom-tool manager delete path, focused tests prove custom-tool
  delete maps to Destructive auth with an explicit reason string, source guards
  prove the button calls the authorization path instead of direct deletion, the
  authorized delete runs only after `.allowed`, denied/unavailable auth performs
  no delete, and the slice stays out of `SovereignGate.swift`, duplicate
  `LocalAuthentication`, custom-tool manager semantics, generated transport,
  Rust, graph files, Omega, ChatCoordinator, subprocesses, solver hot paths,
  tensor copies, and memory hot paths.
- PR11 wired/reachable/visible: the normal Notes Sidebar vault menu
  "Disconnect Vault" action requests shared `SovereignGate` device-owner
  authentication before calling the original vault teardown helper, focused
  tests prove vault disconnect maps to Destructive auth with an explicit reason
  string, source guards prove the button calls the authorization path instead
  of direct disconnect, the authorized disconnect runs only after `.allowed`,
  missing/unavailable auth performs no disconnect, the captured vault URL is
  rechecked after auth, an in-flight guard prevents duplicate prompts/actions,
  and the slice stays out of `SovereignGate.swift`, duplicate
  `LocalAuthentication`, vault teardown semantics, generated transport, Rust,
  graph files, Omega, ChatCoordinator, subprocesses, solver hot paths, tensor
  copies, and memory hot paths.
- PR12 wired/reachable/visible: the existing Authority Settings batch "Reset to
  defaults" footer and Quick Setup preset actions request shared
  `SovereignGate` device-owner authentication before mutating
  `AgentAuthorityStore`, focused tests prove reset/preset targets map to
  Destructive auth with explicit reason strings, source guards prove the button
  closures call authorization helpers instead of direct mutation, denied or
  unavailable auth performs no policy mutation, and the slice stays out of
  `SovereignGate.swift`, duplicate `LocalAuthentication`, authority persistence
  semantics, generated transport, Rust, graph files, Omega, ChatCoordinator,
  subprocesses, solver hot paths, tensor copies, and memory hot paths.
- PR13 wired/reachable/visible: the existing Overseer Settings "Reset history"
  footer requests shared `SovereignGate` device-owner authentication before
  clearing the read-only route/audit trail, focused tests prove history reset
  maps to Destructive auth with an explicit reason string, source guards prove
  the button closure calls the authorization helper instead of direct
  `audit.clear()`, denied or unavailable auth performs no audit clear, and the
  slice stays out of `SovereignGate.swift`, duplicate `LocalAuthentication`,
  programmatic workspace-switch audit clearing, generated transport, Rust,
  graph files, Omega, ChatCoordinator, subprocesses, solver hot paths, tensor
  copies, and memory hot paths.
- PR14 wired/reachable/visible: the existing General Settings "Reset
  Everything" alert keeps its first confirmation but requests shared
  `SovereignGate` device-owner authentication before calling `resetAllData()`,
  focused tests prove reset-everything maps to Destructive auth with an
  explicit reason string, source guards prove the alert calls the authorization
  helper instead of direct reset, denied or unavailable auth performs no reset,
  and the slice stays out of `SovereignGate.swift`, duplicate
  `LocalAuthentication`, unrelated Settings diagnostics edits, generated
  transport, Rust, graph files, Omega, ChatCoordinator, subprocesses, solver
  hot paths, tensor copies, and memory hot paths.
- PR15 wired/reachable/visible: the existing General Settings saved-workspace
  trash button requests shared `SovereignGate` device-owner authentication
  before deleting the saved workspace, focused tests prove saved-workspace
  delete maps to Destructive auth with an explicit reason string, source guards
  prove the button closure calls the authorization helper instead of direct
  delete, denied or unavailable auth performs no delete, and the authorized path
  preserves the original `workspaceService.deleteWorkspace(workspace)` plus
  `refreshWorkspaces()` behavior. The slice stays out of `SovereignGate.swift`,
  duplicate `LocalAuthentication`, workspace service semantics, generated
  transport, Rust, graph files, Omega, ChatCoordinator, subprocesses, solver
  hot paths, tensor copies, and memory hot paths.

Stop triggers:
- A future slice needs generated UniFFI, new lifecycle hooks, Secure Enclave
  sealing, or additional existing dialog migration without naming exact files
  in a new gate.
- `LocalAuthentication`, `LAContext`, `canEvaluatePolicy`, `evaluatePolicy`,
  Touch ID, or biometric prompting appears outside
  `Epistemos/Sovereign/SovereignGate.swift`.
- Swift starts owning the app-action class matrix instead of executing the
  externally supplied requirement.
- Sensitive grace survives explicit clearing, crosses category boundaries,
  accepts invalid durations, survives clock rollback, or applies to destructive
  requirements.

## Card 10 - Hermes Gateway Directness

Status:
Prompt-boundary PR1 is closed. `HermesPromptBuilder.systemPrompt` now states
that Hermes is the tool-call and external-intelligence membrane, not the graph,
Rex, or deterministic substrate authority. It also preserves the direct local
answer path when context is already available, so Hermes stays unified without
becoming a slow wrapper around deterministic substrate work.
Fast-path PR2 is closed. The prompt now names Hermes as the single fast gateway
for cloud models, CLI delegation, MCP/web tools, and explicit external side
effects while saying deterministic local substrate answers must stay on the
direct path and must not pay a gateway hop when no external context is needed.
External evidence returns as structured artifacts and provenance, not graph or
Rex authority.
Tier-boundary PR3 is closed. The prompt now separates local Hermes-family prompt
formatting, which may remain Core-safe only when it runs in-process over local
context, from cloud/provider/CLI/MCP/Hermes subprocess orchestration, which is
Pro/Research only.
Policy PR4 is closed. `HermesGatewayPolicy` is now the tiny pure-Swift source of
truth for deciding whether a Hermes-shaped surface is Core-safe, needs network,
needs subprocess orchestration, or belongs behind the Pro/Research gateway. It
also distinguishes cloud/network need from offline CLI subprocess policy.
App Store Guard PR5 is closed. `HermesGatewayPolicy.isAllowedInCoreAppStoreBuild(_:)`
now allows only direct, no-network, no-subprocess Core surfaces, preserving the
fast substrate path while keeping external gateway surfaces out of Core/App Store.
Route Policy PR6 is closed. `HermesGatewayPolicy` now assigns each surface to
`directSubstrate`, `inProcessLocalPrompt`, or `hermesGateway`, so future runtime
code can keep already-local substrate answers direct, keep local Hermes-family
prompt formatting in-process, and route cloud/CLI/MCP/browser/Docker/external
side-effect work through the single Hermes gateway.
Evidence Return PR7 is closed. `HermesGatewayPolicy` now declares each surface's
return contract: direct substrate work returns no external evidence, local
in-process prompt formatting returns prompt context only, and every unified
Hermes gateway surface must return structured evidence/provenance rather than
graph, Rex, or substrate authority.
Provider Surface Policy PR8 is closed. `HermesGatewayPolicy.Surface.cloudProviderSurfaces`
now names the generic cloud-provider bucket plus OpenAI, Anthropic, Google,
OpenAI-compatible, and Codex account-backed provider surfaces as one cloud
gateway group. `externalGatewaySurfaces` composes from that group so future
provider additions stay single-edit and inherit the same Pro/Research,
`hermesGateway`, network, no-direct-substrate, and structured-provenance
contract.
Hermes Capability Registry PR1 is closed. `HermesCapabilityRegistry` now mirrors
the user's Hermes command/capability target into typed command rows with
surface, tier, owner, network/subprocess/approval/evidence, native-equivalent,
and Hermes-passthrough flags. Focused tests prove every documented command row
has a registry entry, Core/App Store sees only native Core-owned rows, and
Pro/Research keeps Hermes gateway rows visible without granting graph, Rex, or
substrate authority.
Core/MAS Tool Surface Policy PR1 is closed. `ToolSurfacePolicy` now resolves
visible planning surfaces by distribution: real Core/App Store builds and
sandboxed processes use a conservative allow-list, Pro/Research keeps gateway
tools visible for Hermes-controlled operation, `think` stays hidden, and route
primitives such as `route_private` are not advertised in Core. Claude red-team
blocked the initial deny-list shape and then the `route_private` allow-list
entry; both were fixed before merge.
Omega Tool Registry Core Planning PR1 is closed. `OmegaToolRegistry` now exposes
distribution-aware planning schemas, planning JSON, prompt blocks, and
Rust-catalog JSON visibility through `ToolSurfacePolicy`; `MCPBridge.builtinCatalogJson(distribution:)` filters the raw Rust `builtinToolsJson()`
output rather than rebuilding from a Swift mirror. Core/App Store Omega
planning surfaces hide terminal, automation, and computer-use tools, while
Pro/Research catalog names preserve the Rust-visible source of truth. Runtime
MCP registration and `dispatch(_:)` are intentionally unchanged and remain a
future execution-gate slice.
Omega Dispatch Core Execution Gate PR1 is closed. `MCPBridge.dispatch(
_:distribution:)` now applies `ToolSurfacePolicy` before JSON-RPC reaches the
Rust dispatcher: Core/App Store `tools/list` returns the filtered visible tool
set, Core/App Store `tools/call` denies terminal/automation/computer-use tools
as "Tool not found", and Core-safe `read_file` still forwards to Rust. Pro/
Research `tools/list` falls through to the Rust dispatcher when no filtering is
needed. `ToolSurfacePolicy.resolvedDistribution(_:)` is now internal so Omega
can use the same Core/App Store resolution instead of duplicating sandbox
detection.
Command Center Tool Surface Policy PR1 is closed. `AgentCommandCenterState`
now accepts a distribution and applies `ToolSurfacePolicy.surfacedTools` at the
single `rebuildToolCatalog` fan-in, so injected or default tool loaders cannot
surface `run_command`, `get_ui_tree`, or `click` in Core/App Store. The same
filtered list drives `availableTools`, `toolToggles`, and `mcpToolsByAgent`.
Core/App Store context-provider suggestions hide Safari, Terminal, and
Automation while keeping Notes, Files, vault, graph, and open-note context;
manually typed `@Terminal` does not resolve because parsing consumes only the
filtered provider list. Claude red-team found a real catalog-filtering P0 and
then approved the hardened R3 patch with P0=0/P1=0.
Core/MAS ToolTier Execution Symbol Gate PR2 is closed. `ToolTierBridge` now
carries `ToolSurfacePolicy.Distribution` through visible catalog loading and
`toolExecutor()`, and denies non-surfaced Core/App Store tool names before FFI
or bindings execution. The slice keeps the policy in the existing bridge rather
than adding provider, MCP, Omega, or subprocess machinery: hidden gateway symbols
return `Tool not found` in Core/App Store, while Core-safe `vault_search` and
Pro/Research `run_command` execution policy remain allowed.
Overseer Core/MAS Tool Permission Fallback PR1 is closed. `OverseerComplexityRouter`
now exposes a single distribution-aware `fallbackToolPermissions(...)` helper,
and the private route fallback delegates to that helper through
`ToolSurfacePolicy` instead of carrying a raw hardcoded list. Core/App Store
fallback plans keep Core-visible vault/web search tools and hide `run_command`,
`open_url`, `search_web`, browser/computer-use, Docker, and Hermes subprocess
aliases; Pro/Research fallback plans preserve the explicit ask-mode tools for
the Hermes-controlled gateway path.
Core/MAS Boundary Regression Guard PR3 is closed as a test-only closure slice.
`CoreMASBoundarySourceGuardTests` locks the source-level contract across
`HermesGatewayPolicy`, `ToolTierBridge`, and `MCPBridge`: deterministic local
work stays Core/direct/in-process, external gateway surfaces stay Pro/Research,
Core App Store allowance remains a no-network/no-subprocess/direct-substrate
conjunction, Core tools remain in-process, MCP `tools/call` policy denial
happens before Rust dispatch, and boundary files do not host their own Touch ID
prompts or subprocess launchers. `ToolSurfaceBehavioralMatrixTests` exercises
the actual `ToolSurfacePolicy` API so Core is a strict subset of Pro/Research
and `think` stays hidden in every distribution.
Hermes native todo substrate PR55 is closed. `HermesTodoCommand` preserves the
Hermes command shape for `/todo`, `/todo list`, `/todo add <task>`,
`/todo done <id>`, and `/todo clear`, while routing all task state through the
existing Rust `todo` ledger. `agent_core` now accepts `add` and `done` actions
without creating a Swift-side store; `/todo clear` remains approval-marked in
both `HermesCapabilityRegistry` and the native command helper. The command
center exposes `/todo` with the single preferred `todo` tool and local/light
brain preference, not a cloud or subprocess route.
Hermes dispatcher target-sync PR56 is closed. Focused `xcodebuild` proved the
new Hermes/Resonance files are included by Xcode filesystem-synchronized root
groups without manual `project.pbxproj` rows, and `/tokens` now dispatches
through `HermesCommandDispatcher` into the existing Core-native
`HermesTokensCommand`.
Fusion verification floor STEP 2 is closed. The HELIOS WBO-6 budget, Metal
kernel index, KV-Direct gate runbook, red-team prompt fixture, and
`scripts/verify_hotpath.py` are now canonical Epistemos artifacts. The hot-path
verifier passes against current code and maps the mockup `agent_core/metal/`
expectation to the real `Epistemos/Shaders/` shader authority.
WBO-6 Rust budget PR57 is closed. `agent_core::wbo6` is the canonical Rust
budget surface for the six-term bound and integrates with the Resonance seed
through `resonance_core_budget_terms`.
Lattice Rust foundation PR58 is closed. `agent_core::lattice` is the canonical
Core lattice surface for E8 shell counts, Leech metadata/sample handling,
lower-triangular Babai rounding, scalar quantization, and WBO-6 `T_Q` reporting.
Sketch Rust foundation PR59 is closed. `agent_core::sketch` is the canonical
Core L2 Shadow Sketch surface for CountSketch, sparse JL projection, and FRP
projection primitives; runtime graph/RRF wiring stays deferred.
Arena Rust foundation PR60 is closed. `agent_core::arena` is the canonical Rust
mmap/App Group substrate foundation with `group.com.epistemos.shared`, fixed
page-aligned request/response rings, and no Swift/XPC wiring yet.
HELIOS Metal source PR61 is closed. `agent_core/metal/` now holds the six
re-derived substrate seed kernels and they compile with `xcrun metal`; runtime
dispatch and CPU golden references remain future work.

Build Intent:
Use Hermes as the single Pro/Research control surface for cloud models, MCP/web
tools, browser/computer-use, Docker/devcontainer work, and Claude/Codex/Kimi/
Gemini CLI delegation. Keep the Core/App Store path local-first and clean.
Structured external evidence must return through typed artifacts, mutation
envelopes, provenance events, and gates rather than ad hoc graph authority.

Allowed Future Write Set:
- Prompt-only follow-up: `Epistemos/LocalAgent/HermesPromptBuilder.swift`.
- Prompt-only tests: `EpistemosTests/HermesPromptBuilderTests.swift`.
- Pure policy follow-up: `Epistemos/LocalAgent/HermesGatewayPolicy.swift`.
- Capability registry follow-up: `Epistemos/LocalAgent/HermesCapabilityRegistry.swift`.
- Capability registry tests: `EpistemosTests/HermesCapabilityRegistryTests.swift`.
- Pure policy tests: `EpistemosTests/HermesGatewayPolicyTests.swift`.
- Native todo command follow-up: `Epistemos/LocalAgent/HermesTodoCommand.swift`.
- Native todo command tests: `EpistemosTests/HermesTodoCommandTests.swift`.
- Rust todo ledger follow-up: `agent_core/src/tools/todo.rs`.
- Rust todo parity tests: `agent_core/tests/todo_hermes_parity.rs`.
- Runtime/provider slices only after a new gate names exact provider, MCP,
  subprocess, entitlement, auth, event, and projection files.
- Documentation: this card, current state, and a dedicated deliberation note.

Forbidden Without New Gate:
- Direct cloud/provider calls from Core/App Store paths.
- Independent CLI architectures that bypass Hermes/gateway.
- Treating Hermes as Rex, the graph, the deterministic substrate, or source of
  truth for durable state.
- Subprocess launchers, MCP bridges, browser/computer-use, Docker/devcontainer,
  OAuth/auth services, entitlements, Xcode project files, Rust kernels,
  generated bindings, generated libraries, protected graph files, or protected
  note editor files.

Evidence:
- Deliberation:
  `docs/fusion/deliberation/hermes_gateway_directness_pr1_deliberation_2026_05_02.md`.
- Red log:
  `/tmp/epistemos-hermes-gateway-directness-pr1-red-20260502.log`.
- Green log:
  `/tmp/epistemos-hermes-gateway-directness-pr1-green-20260502.log`.
- PR2 Deliberation:
  `docs/fusion/deliberation/hermes_gateway_fast_path_pr2_deliberation_2026_05_02.md`.
- PR2 Red log:
  `/tmp/epistemos-hermes-gateway-fast-path-pr2-red-20260502.log`.
- PR2 Green log:
  `/tmp/epistemos-hermes-gateway-fast-path-pr2-green-20260502.log`.
- PR3 Deliberation:
  `docs/fusion/deliberation/hermes_gateway_tier_boundary_pr3_deliberation_2026_05_02.md`.
- PR3 Red log:
  `/tmp/epistemos-hermes-gateway-tier-boundary-pr3-red-20260502.log`.
- PR3 Green log:
  `/tmp/epistemos-hermes-gateway-tier-boundary-pr3-green-20260502.log`.
- PR4 Deliberation:
  `docs/fusion/deliberation/hermes_gateway_policy_pr4_deliberation_2026_05_02.md`.
- PR4 Red log:
  `/tmp/epistemos-hermes-gateway-policy-pr4-red-20260502.log`.
- PR4 Green log:
  `/tmp/epistemos-hermes-gateway-policy-pr4-green-20260502.log`.
- PR5 Deliberation:
  `docs/fusion/deliberation/hermes_gateway_app_store_guard_pr5_deliberation_2026_05_02.md`.
- PR5 Red log:
  `/tmp/epistemos-hermes-gateway-app-store-guard-pr5-red-20260502.log`.
- PR5 Green log:
  `/tmp/epistemos-hermes-gateway-app-store-guard-pr5-green-20260502.log`.
- PR6 Deliberation:
  `docs/fusion/deliberation/hermes_gateway_route_policy_pr6_deliberation_2026_05_02.md`.
- PR6 Red log:
  `/tmp/epistemos-hermes-gateway-route-pr6-red-20260502.log`.
- PR6 Green log:
  `/tmp/epistemos-hermes-gateway-route-pr6-green-20260502.log`.
- PR7 Deliberation:
  `docs/fusion/deliberation/hermes_gateway_evidence_return_policy_pr7_deliberation_2026_05_02.md`.
- PR7 Red log:
  `/tmp/epistemos-hermes-gateway-evidence-return-pr7-red-20260502.log`.
- PR7 Green log:
  `/tmp/epistemos-hermes-gateway-evidence-return-pr7-green-20260502.log`.
- PR8 Deliberation:
  `docs/fusion/deliberation/hermes_provider_surface_policy_pr8_deliberation_2026_05_02.md`.
- PR8 Red log:
  `/tmp/epistemos-hermes-provider-surface-pr8-red-20260502.log`.
- PR8 Green log:
  `/tmp/epistemos-hermes-provider-surface-pr8-green-20260502.log`.
- PR8 Claude red-team:
  `docs/fusion/fleet/hermes-provider-surface-policy-pr8/claude-red-team/attacks.md`.
- Core/MAS Tool Surface PR1 Deliberation:
  `docs/fusion/deliberation/tool_surface_policy_core_mas_pr1_deliberation_2026_05_02.md`.
- Core/MAS Tool Surface PR1 Red log:
  `/tmp/epistemos-tool-surface-policy-core-mas-pr1-red-20260502.log`.
- Core/MAS Tool Surface PR1 Green log:
  `/tmp/epistemos-tool-surface-policy-core-mas-pr1-green-20260502.log`.
- Core/MAS Tool Surface PR1 Claude red-team:
  `docs/fusion/fleet/tool-surface-policy-core-mas-pr1/claude-red-team/attacks.md`.
- Omega Tool Registry Core Planning PR1 Deliberation:
  `docs/fusion/deliberation/omega_tool_registry_core_planning_pr1_deliberation_2026_05_02.md`.
- Omega Tool Registry Core Planning PR1 Red log:
  `/tmp/epistemos-omega-tool-registry-core-planning-pr1-red-20260502.log`.
- Omega Tool Registry Core Planning PR1 Green log:
  `/tmp/epistemos-omega-tool-registry-core-planning-pr1-green-final-20260502.log`.
- Omega Tool Registry Core Planning PR1 Claude red-team:
  `docs/fusion/fleet/omega-tool-registry-core-planning-pr1/claude-red-team/attacks.md`.
- Omega Dispatch Core Execution Gate PR1 Deliberation:
  `docs/fusion/deliberation/omega_dispatch_core_execution_gate_pr1_deliberation_2026_05_02.md`.
- Omega Dispatch Core Execution Gate PR1 Red log:
  `/tmp/epistemos-omega-dispatch-core-execution-gate-pr1-red-20260502.log`.
- Omega Dispatch Core Execution Gate PR1 Green log:
  `/tmp/epistemos-omega-dispatch-core-execution-gate-pr1-green-r2-20260502.log`.
- Omega Dispatch Core Execution Gate PR1 ToolSurfacePolicy log:
  `/tmp/epistemos-omega-dispatch-core-execution-gate-pr1-tool-surface-green-20260502.log`.
- Omega Dispatch Core Execution Gate PR1 Claude red-team:
  `docs/fusion/fleet/omega-dispatch-core-execution-gate-pr1/claude-red-team/attacks.md`.
- Command Center Tool Surface Policy PR1 Deliberation:
  `docs/fusion/deliberation/command_center_tool_surface_policy_pr1_deliberation_2026_05_02.md`.
- Command Center Tool Surface Policy PR1 Red log:
  `/tmp/epistemos-command-center-tool-surface-pr1-red-20260502.log`.
- Command Center Tool Surface Policy PR1 Green log:
  `/tmp/epistemos-command-center-tool-surface-pr1-green-r3-20260502.log`.
- Command Center Tool Surface Policy PR1 Claude red-team:
  `docs/fusion/fleet/command-center-tool-surface-policy-pr1/claude-red-team/attacks.md`.
- Core/MAS ToolTier Execution Symbol Gate PR2 Deliberation:
  `docs/fusion/deliberation/core_mas_tooltier_execution_symbol_gate_pr2_deliberation_2026_05_03.md`.
- Core/MAS ToolTier Execution Symbol Gate PR2 Red log:
  `/tmp/epistemos-core-mas-tooltier-execution-pr2-red-20260503.log`.
- Core/MAS ToolTier Execution Symbol Gate PR2 Green log:
  `/tmp/epistemos-core-mas-tooltier-execution-pr2-green-20260503.log`.
- Core/MAS ToolTier Execution Symbol Gate PR2 guard log:
  `/tmp/epistemos-core-mas-tooltier-execution-pr2-guard-green-20260503.log`.
- Core/MAS ToolTier Execution Symbol Gate PR2 schema log:
  `/tmp/epistemos-core-mas-tooltier-execution-pr2-schema-green-20260503.log`.
- Core/MAS ToolTier Execution Symbol Gate PR2 Codex red-team:
  `docs/fusion/fleet/core-mas-tooltier-execution-symbol-gate-pr2/claude-red-team/attacks.md`.
- Core/MAS Boundary Regression Guard PR3 focused log:
  `/tmp/epistemos-mas-core-symbol-separation-closure-pr3-20260503.log`.
- Focused command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/HermesGatewayPolicyTests test`.
- Note: PR1 passed 9 focused Swift Testing tests; PR2 passed the expanded
  10-test suite; PR3 passed the expanded 11-test suite; PR4 passed 15 focused
  tests across the policy and prompt suites; PR5 passed the expanded 6-test
  policy suite; PR6 passed the expanded 8-test policy suite; PR7 passed the
  expanded 11-test policy suite; PR8 passed the expanded 13-test policy suite
  after Claude red-team P1 fixes. Core/MAS Tool Surface PR1 passed 7 focused
  `ToolSurfacePolicyTests` after Claude red-team P1 fixes. Omega Tool Registry
  Core Planning PR1 passed 18 focused `ToolSchemaGrammarTests` after Claude
  red-team P1 fixes and one non-blocking P2 cross-source invariant follow-up.
  Omega Dispatch Core Execution Gate PR1 passed 22 focused
  `ToolSchemaGrammarTests` plus the 7-test `ToolSurfacePolicyTests` suite after
  a Claude red-team P1 call-deny coverage fix. Command Center Tool Surface
  Policy PR1 passed 42 focused `AgentCommandCenterStateTests` after Claude
  red-team drove the catalog-filtering hardening. Core/MAS ToolTier Execution
  Symbol Gate PR2 passed 9 focused `ToolSurfacePolicyTests`, 62 guard tests
  across `AgentCommandCenterStateTests` and `AppStoreHardeningTests`, and 22
  focused `ToolSchemaGrammarTests`. Overseer Core/MAS Tool Permission Fallback
  PR1 passed 7 focused `OverseerProtocolTests`; the first green attempt exposed
  a source-shape Swift Testing harness hang, so that structural assertion moved
  into the shell guard list. Core/MAS Boundary Regression Guard PR3 passed 23
  focused Swift Testing tests across `CoreMASBoundarySourceGuardTests` and
  `ToolSurfaceBehavioralMatrixTests`.
  Xcode still printed known SwiftLint package-plugin noise after
  `TEST SUCCEEDED`.

Acceptance:
- PR1 wired: the local Hermes-family system prompt names Hermes as the
  external-intelligence/tool membrane.
- PR1 reachable: focused prompt tests prove the wording stays present.
- PR1 visible: docs now tell future builders that direct local substrate answers
  should not be routed through tools.
- PR1 boundary: no provider, subprocess, MCP, cloud, graph, Rust, generated
  transport, entitlement, protected graph, or protected editor path was touched.
- PR2 wired: Hermes prompt carries the single fast gateway, no gateway tax, and
  structured external evidence invariants.
- PR2 reachable: focused prompt tests prove the fast-path wording stays present.
- PR2 boundary: no provider, subprocess, MCP, cloud, graph, Rust, generated
  transport, entitlement, protected graph, or protected editor path was touched.
- PR3 wired: Hermes prompt separates Core-safe in-process local prompt
  formatting from Pro/Research external gateway orchestration.
- PR3 reachable: focused prompt tests prove the tier-boundary wording stays
  present.
- PR3 boundary: no provider, subprocess, MCP, cloud, graph, Rust, generated
  transport, entitlement, protected graph, or protected editor path was touched.
- PR4 wired: `HermesGatewayPolicy` classifies Core-safe local prompt formatting
  separately from cloud, CLI, MCP/web, Hermes subprocess, browser/computer-use,
  Docker/devcontainer, and explicit external side-effect surfaces.
- PR4 reachable: focused policy tests prove network need and subprocess policy
  remain separate, so Hermes can be unified without implying every path needs
  Wi-Fi.
- PR4 boundary: no provider adapter, subprocess launcher, MCP bridge, cloud
  runtime, graph, Rust, generated transport, entitlement, project, protected
  graph, or protected editor path was touched.
- PR5 wired: `isAllowedInCoreAppStoreBuild(_:)` mechanically rejects every
  external Hermes gateway surface from the Core/App Store lane.
- PR5 reachable: focused tests prove allowed Core/App Store surfaces require no
  network, no subprocess, and preserve the direct substrate path.
- PR5 boundary: no runtime adapter, provider, subprocess, MCP, graph, Rust,
  generated transport, entitlement, project, protected graph, or protected
  editor path was touched.
- PR6 wired: `HermesGatewayPolicy.route(for:)` and `usesHermesGateway(_:)`
  classify direct substrate, in-process local prompt formatting, and unified
  Hermes gateway surfaces.
- PR6 reachable: focused tests prove local work avoids the Hermes gateway route
  while every external gateway surface uses it.
- PR6 boundary: no runtime adapter, provider, subprocess, MCP, browser,
  Docker/devcontainer, graph, Rust, generated transport, entitlement, project,
  protected graph, or protected editor path was touched.
- PR7 wired: `evidenceReturn(for:)` and
  `requiresStructuredEvidenceReturn(_:)` map direct, in-process, and external
  gateway surfaces to explicit evidence-return contracts.
- PR7 reachable: focused tests prove local surfaces do not require structured
  external evidence while every Hermes gateway surface does.
- PR7 boundary: no runtime adapter, provider, subprocess, MCP, browser,
  Docker/devcontainer, graph, Rust, generated transport, entitlement, project,
  protected graph, or protected editor path was touched.
- PR8 wired: named cloud provider surfaces are first-class cloud gateway policy
  cases, and the legacy generic `.cloudProvider` case is included in the same
  group.
- PR8 reachable: focused tests prove every cloud-provider surface is
  Pro/Research, `hermesGateway`, network-required, not subprocess-required, not
  direct-substrate, not Core/App Store-allowed, and structured-provenance
  returning.
- PR8 red-team closed: Claude found the initial cloud-provider group was not
  exhaustive and the external gateway list duplicated provider cases; both were
  fixed by composing `externalGatewaySurfaces` from `cloudProviderSurfaces` and
  adding a regression test.
- PR8 boundary: no runtime adapter, provider, subprocess, MCP, browser,
  Docker/devcontainer, graph, Rust, generated transport, entitlement, project,
  protected graph, or protected editor path was touched.
- Command Center PR1 wired: `AgentCommandCenterState` carries a distribution
  and applies `ToolSurfacePolicy` to the loaded tool catalog at one fan-in.
- Command Center PR1 reachable: focused tests prove Core/App Store filters
  injected `run_command`, `get_ui_tree`, and `click` while Pro/Research keeps
  them.
- Command Center PR1 visible: focused tests prove Core/App Store hides Safari,
  Terminal, and Automation context providers and rejects manual `@Terminal`
  parsing while preserving Notes/Files context.
- Command Center PR1 boundary: no Omega, Engine, view, Rust, generated,
  entitlement, project, provider, graph, or execution-path files were touched.
- Overseer fallback PR1 wired: degraded-registry route permissions delegate to
  `fallbackToolPermissions(distribution: .currentBuild)`.
- Overseer fallback PR1 reachable: focused tests prove Core/App Store fallback
  hides Pro gateway aliases while Pro/Research preserves explicit ask-mode
  fallback entries.
- Overseer fallback PR1 boundary: no provider, MCP, Omega, Rust, generated,
  entitlement, project, graph, view, or execution-path bridge files were
  touched.

Stop Triggers:
- A future slice wants to execute a provider request, shell command, MCP call,
  browser/computer-use action, or Docker/devcontainer route without a new exact
  runtime gate.
- A prompt or runtime path frames Hermes as graph/Rex/substrate authority.
- Direct local answers start taking tool hops when the necessary context is
  already available.

## Card 11 - RRF QueryRuntime Phase-4 Recovery

Status on 2026-05-03:

- PR34 recovers the RRF Phase 4 site 3 wiring that canon already claimed:
  `RetrievalRuntime.fullText(query:scope:)` uses
  `SearchIndexService.fusedSearch(query:weights:now:)` only when
  `RRFFusionFlags.isEnabled && scope == .all`.
- Flag-off, `.pages`, `.blocks`, and fused-path failure preserve the existing
  legacy page/block search dispatch.
- Claude Red Team found the missing reactive dependency; PR34 now adds
  `QueryDependencyKey.searchReadable` and `ReadableBlocksIndex` invalidation so
  `.all` reactive surfaces do not go stale when only the universal readable
  projection changes.
- The slice updates `MASTER_RESEARCH_INDEX_2026_05_02.md` so future sessions can
  find Swift RRF Cross-Index Fusion directly instead of discovering it via Halo
  RRF aliases.

Allowed write set:

- `Epistemos/Engine/QueryRuntime.swift`
- `Epistemos/Models/QueryTypes.swift`
- `Epistemos/Sync/ReadableBlocksIndex.swift`
- `EpistemosTests/QueryRuntimeTests.swift`
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- Round 66 fleet, deliberation, registry, current-state, and guard docs.

Forbidden write set:

- `Epistemos/Sync/SearchIndexService.swift`
- `Epistemos/Sync/RRFFusionQuery.swift`
- `Epistemos/Sync/VaultSyncService.swift`
- `Epistemos/Views/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- `epistemos-core/**`
- generated bindings, entitlements, and Xcode project files.

Tests and logs:

- PR34 green log:
  `/tmp/epistemos-query-runtime-rrf-fused-fulltext-pr34-green-r3-20260503.log`.
- Focused command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-pr34-r3 -parallel-testing-enabled NO -only-testing:EpistemosTests/QueryRuntimeTests test`.
- Note: this host's SQLite lacks FTS5, so the readable-block-only fused behavior
  test skips behind the existing fusion gate; non-skipped fallback, non-`.all`
  scope, reactive invalidation, and source guards pass.
- ReadableBlocksIndex focused log:
  `/tmp/epistemos-query-runtime-rrf-fused-fulltext-pr34-readable-green-20260503.log`.

Acceptance:

- PR34 wired: `.all` full-text retrieval can use the single-SQL RRF path behind
  `EPISTEMOS_RRF_FUSION_V1`.
- PR34 reachable: source guards prove the path is flag-gated and falls back.
- PR34 verified: focused `QueryRuntimeTests` pass with 32 tests in 1 suite.
- PR34 boundary: no SearchIndexService, RRF SQL, VaultSyncService, UI, graph,
  Rust, generated, default-flag, or Phase 6 dogfood/default-flip path was
  touched.
- PR35 wired: Settings Diagnostics now mounts a read-only Search Fusion Health
  row backed by `SearchFusionMetrics`.
- PR35 reachable: `SearchFusionMetrics` publishes a lightweight change
  notification and `SearchFusionHealthRow` refreshes from that event instead of
  polling.
- PR35 verified: focused `SearchFusionHealthRowTests` pass with 4 tests in 1
  suite.
- PR35 boundary: no RRF SQL scoring, QueryRuntime, VaultSyncService, graph,
  Rust, generated, dogfood-completion, or default-flag flip path was touched.

Stop triggers:

- A future RRF slice flips the feature flag default without a Phase 6 runtime
  dogfood gate.
- A future RRF slice routes Rust agent tools or Hermes grammar through Swift
  fusion without the deferred FFI bridge design.
- A future QueryRuntime slice edits graph renderer, GraphEvent writes, OpLog,
  MutationEnvelope, or Halo surfaces without a fresh gate.
