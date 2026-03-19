# Performance Audit

## Verified improvements

1. Ring head/tail cache-line separation is explicit and tested.
2. Producer-side archive temp buffer was removed from staged knowledge-core.
3. Shared-memory shadow consumer avoids `Data` and JSON in transport.

## Verified performance risks

1. Fresh Cozo DB creation and full relation import on every relevant query.
2. Repeated per-row FFI helper calls in staged Swift consumer.
3. Live query UI still has coarse 150 ms invalidation behavior.
4. Parser is still string-heavy and line-based.
5. Knowledge-core CRDT wrapper does not expose or benchmark real multi-peer merge paths.

## Bottom line

The transport layer is ahead of the query and parsing layers. Latency claims for the full architecture are still not proven.
