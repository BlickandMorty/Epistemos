# R16 ETL Worker Execution PR3H Deliberation - 2026-05-01

## Decision

Approved for a narrow R16 PR3H slice that makes ETL queued jobs execute through
an honest Rust worker completion contract. The worker may only mark a job done
after validating that the queued file still exists, is readable, and matches the
queued fingerprint.

## Scope

- Add a Rust ETL worker module that validates `EtlIngestJob` inputs by
  re-reading the queued file and recomputing the same path+content fingerprint
  used at enqueue time.
- Add a bounded raw C ABI `etl_run_worker_json(queue_path, max_jobs)` that opens
  the existing Apalis SQLite queue, runs the validation worker for up to
  `max_jobs`, and returns JSON counts for attempted, succeeded, failed, and
  post-run queue stats.
- Add Swift decoding/wrapper types for the new FFI result.
- Call the worker from the existing off-main Shadow/ETL bootstrap path after
  successful enqueue and after the existing `PowerGate.shouldDefer()` gate.
- Add red-first Rust and Swift tests proving jobs drain to `done` only through
  validation and missing/bad jobs do not become fake successes.

## Explicit Non-Scope

- No Rust-to-Swift callbacks.
- No AFM sidecar generation changes or duplicate sidecar generation path.
- No new queue schema, sidecar schema, or database family.
- No `PowerGate`, MAS bookmark, model-derived badge, or Shadow dispatch
  rewrites beyond calling the new bounded worker at the existing dispatch site.
- No protected editor, graph renderer/controller, `graph-engine/**`,
  `epistemos-shadow/**`, generated binding, entitlement, project, plist,
  staging, commit, stash, or branch operations.

## Rationale

Previous Kimi advisory rejected no-op drains and synchronous callback shortcuts.
Kimi's PR3H advisory recommended a built-in Rust handler that validates file
existence and fingerprint before completion. This keeps queue completion honest
while preserving the existing Swift AFM sidecar generation source of truth.

## Files

- `agent_core/src/etl/worker.rs` (new)
- `agent_core/src/etl/mod.rs`
- `agent_core/src/etl/ffi.rs`
- `Epistemos/Engine/RustShadowFFIClient.swift`
- `Epistemos/App/AppBootstrap.swift`
- `EpistemosTests/ShadowVaultBootstrapperTests.swift`
- Fusion docs for results and oversight.

## Acceptance

- Red-first Rust ETL tests fail before implementation.
- Red-first Swift focused tests fail before implementation.
- Green Rust ETL tests pass after implementation.
- Green focused Swift `ShadowVaultBootstrapperTests` pass after implementation.
- Queue jobs reach `done` only when the worker successfully validates the file
  and fingerprint.
- Missing or fingerprint-mismatched files are counted as failures and do not
  inflate `done`.
- The app path remains off-main and bounded by `max_jobs`.

## Stop Triggers

- The worker marks jobs successful without reading and validating the file.
- The implementation needs a synchronous Swift callback from Rust.
- The implementation changes sidecar generation, queue schema, or MAS bookmark
  policy.
- The implementation requires project/generated binding edits.
- The worker blocks the main actor or bypasses `PowerGate.shouldDefer()`.
