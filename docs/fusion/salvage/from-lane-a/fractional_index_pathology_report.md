# Fractional Index Pathology Report

## Implementation audited

- live/shared custom index: [fractional_index.rs](/Users/jojo/Epistemos/graph-engine/src/block_kernel/fractional_index.rs)
- staged Loro wrapper projects custom order keys through the same type

## What is true

- ordering uses base-256-like digit bytes
- tie-breakers include `peer_id` and `discriminator`
- repeated insertions can extend digits instead of renumbering all siblings

## Tests present

- `between_orders_between_neighbors`
- `collision_uses_peer_and_discriminator_tie_breakers`
- `repeated_insertions_reset_by_extending_digits`
- `alternating_gap_inserts_remain_strictly_sorted`
- `inverted_neighbors_fall_back_after_left`
- `sort_key_roundtrips`

## What is missing from the brief

- no true random jitter generation
- no explicit rebalance/reset algorithm
- no way to create a true strict-between value once two siblings share the same digit vector and differ only by peer/discriminator tie-breakers; the current fallback extends digits and lands after that collision window
- no proof against long-run pathological growth under hostile concurrent inserts
- no multi-peer same-position integration test in staged knowledge-core

## Conclusion

The current implementation is competent and deterministic for the happy path. It is not the fully hardened “base-256 + jitter + reset” system described in the brief.
