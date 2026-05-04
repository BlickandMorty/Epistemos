# R16 Bootstrapper ETL Dispatch PR3D Deliberation - 2026-05-01

## Verdict

Approved for a narrow PR3D slice that turns the existing R16 ETL queue
foundation from diagnostics-only into a real bootstrap dispatch path.

This gate authorizes one Rust C ABI enqueue-walk endpoint plus the Swift caller
needed to invoke it after Shadow vault bootstrap. It also authorizes an honest
paused diagnostics state driven by `PowerGate.shouldDefer()`.

This gate does not approve editor badge UI, MAS bookmark migration work,
generated UniFFI bindings, graph-engine work, protected note editor work, or
ETL worker execution.

## Scope

- Add a raw C ABI function in `agent_core/src/etl/ffi.rs` that:
  - accepts `vault_path` and `queue_path`;
  - walks the vault with the existing `crawl_vault`;
  - builds `EtlIngestJob` values through the existing job/fingerprint code;
  - enqueues supported jobs into the existing `EtlQueue`;
  - returns JSON with `available`, `total`, `queued`, `skipped`, and `error`.
- Add a Swift `RustEtlQueueDispatchClient` wrapper in the existing raw FFI
  client file.
- In `AppBootstrap.initializeShadowBackendIfReady()`, after Shadow bootstrap
  and flush, call the dispatch endpoint unless `PowerGate.shouldDefer()` says
  the background job should pause.
- Extend `BackgroundIndexingHealthRow` with a paused phase so Settings
  Diagnostics can display "Paused - on battery/thermal/low power" instead of
  falsely showing complete/running.

## Authority Evidence

- `docs/plan/03_EXECUTION_MAP.md` R16 mandates ETL state visibility in
  Settings and battery/thermal pause via `PowerGate.shouldDefer()`.
- `docs/plan/00_AUTHORITY_AND_ANTI_DRIFT.md` requires background jobs to yield
  under memory/thermal pressure and forbids silent sidecar activation.
- `docs/fusion/deliberation/r16_etl_pr3_background_indexing_status_shell_deliberation_2026_05_01.md`
  reserved PR3D for ShadowVaultBootstrapper ETL dispatch and pause UI.
- `agent_core/src/etl/` already contains `crawl_vault`, `EtlIngestJob`, and
  `EtlQueue`; this slice reuses those instead of inventing another queue.
- `Epistemos/App/AppBootstrap.swift` already opens Shadow, crawls notes/chats,
  samples ETL stats, and owns the correct production point to dispatch the
  queue after Shadow indexing.
- `Epistemos/State/PowerGate.swift` is the canonical battery/thermal predicate
  for background work.

## Allowed Files

- `agent_core/src/etl/ffi.rs`
- `Epistemos/Engine/RustShadowFFIClient.swift`
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/Views/Settings/EditorBundleHealthRow.swift`
- `EpistemosTests/ShadowVaultBootstrapperTests.swift`
- `docs/fusion/deliberation/r16_bootstrapper_etl_dispatch_pr3d_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_034_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

## Forbidden Files

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- `epistemos-shadow/**`
- `agent_core/**` except `agent_core/src/etl/ffi.rs`
- Xcode project/workspace files, entitlements, generated UniFFI bindings,
  generated libraries, DerivedData, `.xcresult`, staging, commit, stash, or
  branch operations.

## Implementation Contract

- The dispatch endpoint may create the ETL queue database because it is the
  production enqueue path; the stats endpoint must remain non-creating for
  diagnostics.
- Source-code exclusion remains owned by the existing Rust walker and job kind
  filters.
- AppBootstrap must dispatch only after Shadow bootstrap has flushed.
- If `PowerGate.shouldDefer()` returns true, AppBootstrap records a paused
  diagnostic and does not enqueue ETL work.
- ETL enqueue failure is nonfatal to app launch and Shadow/Halo availability.
- No full R16 WRV claim is made; worker execution, sidecar badge UI, and MAS
  bookmark enforcement remain future gates.

## Tests

- `cargo test --manifest-path agent_core/Cargo.toml etl --lib`
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ShadowVaultBootstrapperTests test`
- Diff and protected-path guardrails for the allowed files and docs.

## Acceptance

- Rust FFI test proves the enqueue endpoint creates a queue and pending jobs
  for supported vault files without queueing source-code files.
- Swift tests prove paused diagnostics and ETL dispatch snapshots are recorded
  correctly.
- AppBootstrap records live queue stats after dispatch.
- The Settings row can visibly distinguish indexing, complete, failed, and
  paused states.

## Stop Triggers

- The implementation needs generated UniFFI binding changes.
- The implementation needs `epistemos-shadow/**` or `graph-engine/**`.
- The implementation needs protected note editor/graph view files.
- The enqueue endpoint queues `.swift`, `.rs`, `.py`, `.json`, `.toml`, build,
  or source-control files.
- A focused Rust or Swift test fails and cannot be fixed inside the allowed
  write set.

## WRV

Intermediate WRV for PR3D only:

- Wired: AppBootstrap calls the ETL dispatch endpoint after Shadow bootstrap.
- Reachable: opening/restoring a vault triggers the existing Shadow bootstrap
  path.
- Visible: Settings Diagnostics shows queue counts or paused state through
  `BackgroundIndexingHealthRow`.

Full R16 WRV remains deferred until worker execution, generated sidecar badge
visibility, memory-pressure pause, and MAS bookmark enforcement land.
