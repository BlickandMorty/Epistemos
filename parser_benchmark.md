# Parser Benchmark

## Status

No dedicated knowledge-core parser throughput benchmark exists yet in the repo.

## What was verified instead

- targeted parser tests pass
- the parser uses line iteration plus `memmem`, not regex-heavy scanning

## Recommendation

Add a release-mode benchmark for:

- large Markdown file
- large Org file
- mixed task/link/property content

until then, parser latency claims remain unproven.
