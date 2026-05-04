# Schema Gap Report

## Implemented in staged knowledge-core

- `block(page, block => parent, ord, depth, content)`
- `task(page, block => marker, done)`
- `prop(page, block, key => value)`
- `link(page, block, target => ref_type)`

## Missing relative to the requested schema

- page relation
- tag relation
- ref/backlink relation distinct from generic link
- task scheduling fields
- property typing beyond string values
- first-class ordering metadata relation
- watcher metadata relation
- transaction log relation

## Conclusion

The staged schema is enough for outline/tasks/properties/links demos. It is not yet a full Epistemos knowledge schema.
