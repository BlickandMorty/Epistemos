# Risk Register

## Correctness risks

1. Cozo is query-only, not authoritative state.
2. Live UI is not driven by typed Rust diffs.
3. Parser architecture claim still exceeds the real implementation.
4. Staged FFI mutators collapse all errors to `0`.

## Performance risks

1. Fresh Cozo DB build/import on every relevant query.
2. Per-row FFI helper calls and repeated archive validation.
3. Swift string/array materialization on every staged payload.
4. Live query invalidation floor remains about 150 ms.

## Operational risks

1. Manual header maintenance can drift.
2. No fuzz harness for malformed archived payloads.
3. Shadow polling lifecycle is not yet tied to visible subscription count.
