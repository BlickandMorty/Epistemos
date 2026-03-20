# Parser Benchmark

## Current benchmark

Measured command:

```bash
cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml \
  benchmark_knowledge_core_parser_markdown_large_document \
  -- --ignored --nocapture
```

Measured result:

- `25566313 ns/parse`
- `3.05 MB/s`

## Scope

- synthetic large Markdown document
- debug-build microbenchmark inside the unit-test harness
- validates the current line-based parser scaffold only

## What remains missing

- release-mode parser benchmark
- large Org benchmark
- mixed task/link/property benchmark
- parser allocation-count instrumentation

Until those exist, parser latency claims remain limited and architectural claims remain unproven.
