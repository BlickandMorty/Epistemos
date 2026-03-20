# Benchmark Baseline

## Ring producer baseline

Measured command:

```bash
cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml \
  knowledge_core::ring::tests::benchmark_archived_write_vs_temp_buffer_path \
  --release -- --ignored --nocapture
```

Baseline path:

- archive into temporary buffer
- copy buffer into ring slot

Measured result:

- `175 ns/write`

## Live query baseline

Code-inspection baseline only:

- `GraphStore` debounce: 50 ms
- `ReactiveQuery` debounce: 100 ms
- effective invalidation floor: about 150 ms before view work

This second value is architectural, not benchmarked.

## Staged summary decode baseline

Measured command:

```bash
cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml \
  benchmark_knowledge_core_payload_summary_accessor \
  -- --ignored --nocapture
```

Baseline path:

- `graph_engine_kc_payload_tx_id`
- `graph_engine_kc_payload_subscription_id`
- `graph_engine_kc_payload_kind`
- `graph_engine_kc_subscription_kind`
- `graph_engine_kc_payload_row_count` x 3

Measured result:

- `23989 ns/decode`
