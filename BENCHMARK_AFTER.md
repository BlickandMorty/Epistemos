# Benchmark After

## Ring producer after direct archive write

Same command as baseline.

Improved path:

- archive directly into reserved ring slot payload

Measured result:

- `64 ns/write`
- measured speedup vs temp-buffer path: `2.70x`

## Interpretation

This validates the specific producer-side copy removal. It does not prove end-to-end UI latency.

## Staged summary decode after combined accessor

Command:

```bash
cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml \
  benchmark_knowledge_core_payload_summary_accessor \
  -- --ignored --nocapture
```

Improved path:

- one `graph_engine_kc_payload_summary(...)` call per staged summary
- one archive validation instead of the old scalar accessor sequence

Measured result:

- `5481 ns/decode`
- measured speedup vs scalar summary accessors: `6.21x`

## Interpretation

This validates one specific consumer-side hot-path reduction on the staged bridge. It does not remove row materialization costs and it does not prove full-frame UI latency.

## Staged row decode after batched row accessor

Command:

```bash
cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml \
  benchmark_knowledge_core_payload_rows_batch_accessor \
  -- --ignored --nocapture
```

Improved path:

- one `graph_engine_kc_payload_rows(...)` call per staged row section
- one archive validation per section instead of one `graph_engine_kc_payload_row(...)` call per row

Measured result:

- scalar row accessor loop: `12506 ns/payload`
- batched row accessor: `3807 ns/payload`
- measured speedup vs scalar row accessors: `3.28x`

## Interpretation

This validates the next consumer-side reduction after the summary accessor change. It reduces FFI chatter and repeated validation, but it still does not remove Swift-owned string/array materialization.
