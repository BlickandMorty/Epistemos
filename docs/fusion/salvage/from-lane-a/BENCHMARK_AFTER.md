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

- `3773 ns/decode`
- measured speedup vs scalar summary accessors: `6.36x`

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

- scalar row accessor loop: `19825 ns/payload`
- batched row accessor: `5710 ns/payload`
- measured speedup vs scalar row accessors: `3.47x`

## Interpretation

This validates the next consumer-side reduction after the summary accessor change. It reduces FFI chatter and repeated validation, but it still does not remove Swift-owned string/array materialization.

## Staged outline watcher after incremental refresh

Command:

```bash
cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml \
  benchmark_knowledge_core_incremental_outline_refresh \
  -- --ignored --nocapture
```

Improved path:

- one resident staged Cozo `DbInstance`
- staged mutations mirror into resident relations instead of rebuilding Cozo per query
- matched outline subscriptions update only touched row identities

Measured result:

- incremental watcher refresh: `84380 ns/tx`
- control full-rerun path: `6621173 ns/tx`
- measured speedup vs full rerun: `78.47x`

## Interpretation

This is the biggest gain from the Phase 2/3 pass. It validates that the staged watcher hot path no longer pays the old “full Cozo rebuild + full query rerun” tax on matching updates.

## Live BTK property watcher after incremental refresh

Command:

```bash
cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml \
  benchmark_property_subscription_incremental_refresh \
  -- --ignored --nocapture
```

Improved path:

- matched BTK property subscriptions now refresh directly from touched property facts
- full Cozo reruns are skipped for those matched property updates

Measured result:

- incremental watcher refresh: `6842546 ns/tx`
- control full-rerun path: `12698080 ns/tx`
- measured speedup vs full rerun: `1.86x`

## Interpretation

This is a smaller but still real win in the live BTK helper path. It is intentionally narrower than the staged-store win because linked-reference traversal subscriptions still use the old full-rerun path.

## Staged parser scaffold throughput

Command:

```bash
cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml \
  benchmark_knowledge_core_parser_markdown_large_document \
  -- --ignored --nocapture
```

Measured result:

- `25566313 ns/parse`
- `3.05 MB/s`

## Interpretation

This is a coarse debug-build microbenchmark for the current line parser. It proves the parser is no longer unmeasured, but it does not prove the event-normalized parser architecture from the brief.
