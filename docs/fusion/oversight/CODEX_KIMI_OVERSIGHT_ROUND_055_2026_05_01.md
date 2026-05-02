# CODEX/KIMI Oversight Round 055 - R16 ETL Worker Execution PR3H

## Scope

R16 PR3H closes honest ETL worker execution for queued vault-ingest jobs. The
worker may only mark jobs complete after validating the queued file still
matches the enqueue-time fingerprint contract.

## Kimi Input

Kimi advisory attempts with file access hit max-step limits:

- `/tmp/epistemos-r16-etl-worker-execution-kimi-advisory-20260501.log`
- `/tmp/epistemos-r16-etl-worker-execution-kimi-advisory-20260501-r2.log`

The no-tool advisory completed:

- `/tmp/epistemos-r16-etl-worker-execution-kimi-advisory-20260501-r3.log`

Kimi's usable recommendation was to avoid no-op drains and Rust-to-Swift
callbacks, add one bounded worker C ABI, validate file existence/readability and
fingerprint before completion, add a Swift wrapper, and call it after the
existing enqueue path.

## Change Summary

- Added `agent_core/src/etl/worker.rs` with file validation and a bounded
  validation worker summary.
- Added `etl_run_worker_json(queue_path, max_jobs)` to the Rust ETL C ABI.
- Added `EtlQueueWorkerSnapshot` and `RustEtlQueueWorkerClient.run(...)` on the
  Swift side.
- Wired `AppBootstrap.initializeShadowBackendIfReady()` so the off-main
  Shadow/ETL path runs the worker after ETL enqueue when `PowerGate` is not
  deferring.
- Added Rust and Swift focused tests proving jobs drain to `done` after
  validation and missing/stale jobs do not become fake successes.

## Evidence

Red-first:

- `/tmp/epistemos-r16-etl-worker-pr3h-red-cargo-20260501.log`
- `/tmp/epistemos-r16-etl-worker-pr3h-red-xcode-20260501.log`
- `/tmp/epistemos-r16-etl-worker-pr3h-red-summary-20260501.log`

Green:

- `/tmp/epistemos-r16-etl-worker-pr3h-green-cargo-20260501.log`
  - `2` ETL FFI worker tests passed.
- `/tmp/epistemos-r16-etl-worker-pr3h-green-cargo-worker-20260501.log`
  - `3` ETL validation tests passed.
- `/tmp/epistemos-r16-etl-worker-pr3h-green-cargo-etl-full-20260501.log`
  - `25` ETL tests passed.
- `/tmp/epistemos-r16-etl-worker-pr3h-green-xcode-20260501.log`
  - `12` tests in `ShadowVaultBootstrapper (Wave 8.7)` passed.
- `/tmp/epistemos-r16-etl-worker-pr3h-green-summary-20260501.log`

Additional guardrail:

- `cargo fmt --manifest-path agent_core/Cargo.toml -- --check` passed.
- `nm -gU build-rust/libagent_core.dylib` showed `_etl_run_worker_json`.
- Targeted grep confirmed AppBootstrap calls
  `RustEtlQueueWorkerClient.run(...)` after
  `RustEtlQueueDispatchClient.enqueueVaultWalk(...)` and after
  `PowerGate.deferSnapshot()`.

## Non-Claims

- No Rust-to-Swift callback is added.
- No AFM sidecar generation behavior is changed.
- No sidecar schema, queue schema, MAS bookmark policy, protected editor,
  protected graph, generated binding, Xcode project, plist, or entitlement
  behavior is changed.
- This is not a full R16 manual runtime ship claim.

## Remaining R16 Work

- Runtime/manual verification against a real user vault remains required before
  product-ready claims.
- Any throughput/backfill/productization work must get a new exact gate.
