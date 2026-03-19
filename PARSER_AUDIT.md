# Parser Audit

## Verdict

`FAIL` for the design claim, with one targeted regression fix landed.

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

## Fix landed during audit

The staged colon-property branch was effectively dead. It now parses inline `:key:value:` tokens, with regression coverage in:

- `org_normalizes_headings`

## Remaining gaps

- no actual parser-event normalization into a canonical AST
- no property-drawer support
- no block reference/transclusion normalization beyond basic wikilinks
- many `String` allocations per line

## Conclusion

The staged parser is a practical scaffold. It is not the architecture described in the brief.
