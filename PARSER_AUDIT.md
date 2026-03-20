# Parser Audit

## Verdict

`FAIL` for the design claim, with two targeted staged-parser fixes landed.

## What the code actually does

Evidence:

- [parser.rs](/Users/jojo/Epistemos/graph-engine/src/knowledge_core/parser.rs)

Behavior:

- `parse_markdown` instantiates `pulldown-cmark` and counts events
- `parse_org` instantiates `orgize` and counts events
- both then fall back to `parse_lines(...)`

This is not a true event-normalized shared AST pipeline.

## Good parts

- `memchr::memmem` is used for wikilink scanning
- parsing is allocation-light enough for a staged line parser
- task/link/property normalization exists for simple cases

## Fixes landed during audit

- The staged colon-property branch was effectively dead. It now parses inline `:key:value:` tokens, with regression coverage in:
- `org_normalizes_headings`
- Basic Org property drawers now attach to the preceding heading instead of becoming fake blocks:
- `org_property_drawers_attach_to_previous_heading`

## Benchmark evidence

Command:

```bash
cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml \
  benchmark_knowledge_core_parser_markdown_large_document \
  -- --ignored --nocapture
```

Measured result:

- `25566313 ns/parse`
- `3.05 MB/s`

This is a coarse debug-build microbenchmark for the current line parser. It does not prove the parser meets the brief.

## Remaining gaps

- no actual parser-event normalization into a canonical AST
- no block reference/transclusion normalization beyond basic wikilinks
- many `String` allocations per line

## Conclusion

The staged parser is a practical scaffold. It is not the architecture described in the brief.
