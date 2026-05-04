# Go / No-Go

## Decision

`NO-GO` for replacing the current runtime.

Current category:

- `C. not ready; keep as parallel/staged path`

## Evidence

- default app runtime still uses BTK + Swift query execution
- staged knowledge-core is feature-flagged only
- Cozo is not authoritative or persistent
- parser is not truly event-normalized
- staged Swift consumer still copies into UI snapshots
- full end-to-end UI latency is not benchmarked

## What is ready

- shadow-mode shared-memory transport benchmarking
- staged diff draining
- staged CRDT and parser scaffolding

## What is not ready

- authoritative runtime replacement
- parity cutover
- production performance claims
