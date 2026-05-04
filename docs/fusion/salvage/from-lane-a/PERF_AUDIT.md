# Performance Audit

## Verified improvements

1. Ring head/tail cache-line separation is explicit and tested.
2. Producer-side archive temp buffer was removed from staged knowledge-core.
3. Shared-memory shadow consumer avoids `Data` and JSON in transport.
4. Staged Cozo watcher refresh no longer rebuilds Cozo on matched outline updates.
5. Parser now has a coarse throughput benchmark instead of zero measurement.

## Verified performance risks

1. Live BTK linked-reference queries and initial snapshots still rebuild fresh in-memory Cozo state.
2. Swift still materializes arrays and `String`s for every staged payload snapshot.
3. Live query UI still has coarse 150 ms invalidation behavior.
4. Parser is still string-heavy and line-based.
5. Knowledge-core CRDT wrapper does not expose or benchmark real multi-peer merge paths.

## Bottom line

The transport layer is ahead of the query and parsing layers. Latency claims for the full architecture are still not proven.
