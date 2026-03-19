# Fuzz Plan

## Priority 1

- malformed ring slot headers
- truncated archived payloads
- invalid section/index accesses for `graph_engine_kc_payload_row`
- ring boundary arithmetic around full/empty transitions

## Priority 2

- fractional-index ordering under repeated same-position inserts
- CRDT restore/delete/move interleavings
- parser fuzz for malformed Org/Markdown tokens and link delimiters

## Priority 3

- Swift bridge lifecycle fuzz:
  - subscribe/unsubscribe churn
  - start/stop polling races
  - drain while tail/head advance

## Goal

Catch boundary-case UB and stalled-consumer cases before any production cutover.
