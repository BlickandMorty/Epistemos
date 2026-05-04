# Risk Register

## Correctness risks

1. Cozo is query-only, not authoritative state.
2. Live UI is not driven by typed Rust diffs.
3. Parser architecture claim still exceeds the real implementation.
4. Staged FFI mutators collapse all errors to `0`.

## Performance risks

1. Live BTK linked-reference queries and snapshot paths still rebuild fresh in-memory Cozo state.
2. Swift string/array materialization still dominates every staged payload decode.
3. Live query invalidation floor remains about 150 ms.
4. Parser remains line-based and string-heavy even after the property-drawer fix.

## Operational risks

1. Manual header maintenance can drift.
2. No fuzz harness for malformed archived payloads.
3. Shadow polling lifecycle is not yet tied to visible subscription count.
