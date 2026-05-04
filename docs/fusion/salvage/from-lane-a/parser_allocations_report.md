# Parser Allocations Report

## Main allocation sources

Evidence:

- [parser.rs](/Users/jojo/Epistemos/graph-engine/src/knowledge_core/parser.rs)

Allocations per non-empty line commonly include:

- `block_id` formatting
- `order_key` formatting
- cloned `page_id`
- cloned `parent_id`
- cloned `content`
- per-property key/value strings
- per-link target strings

## Efficient parts

- link scanning uses `memmem`
- parser does not build a full external AST today

## Main conclusion

The staged parser avoids giant tree allocation, but it is still string-heavy and line-materialization-heavy.
