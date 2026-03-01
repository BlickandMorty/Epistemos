# Audit Progress
Last updated: 2026-03-01 16:00

## Current Position
Wave: 1 | Item: 1.7 | Gate: 1 (DIAGNOSE + TEST-FIRST)

## Session Stats
Tests before: 551 (Rust) + 227 suites (Swift) | Tests after: 551 (Rust) | New tests: 1
Fixes this session: 2 | Deferred: 0

## Pre-Audit Fixes
- [x] Keychain Data Protection migration (commit efd2ab6) — not audit item
- [x] 11 stale Rust test assertions fixed (commit 9abb941) — not audit item

## Completed
- [x] 1.1: Per-Node Highlight Flag Buffer — ALREADY IMPLEMENTED
- [x] 1.2: Pre-Allocate Scratch Buffers — ALREADY IMPLEMENTED (FxHashMap collision_grid + bodies_scratch)
- [x] 1.3: Pre-Allocate Field Line Buffer — ALREADY IMPLEMENTED (field_line_buffer with capacity tracking)
- [x] 1.4: Straight-Line Edges — ALREADY IMPLEMENTED (EDGE_SEGMENTS=1, bezier removed)
- [x] 1.5: Remove Motion Blur — ALREADY IMPLEMENTED (no offscreen textures, direct render)
- [x] 1.6: List Virtualization — ALREADY IMPLEMENTED (LazyVStack used everywhere)
- [x] 6.1: Graph Version Tracking — NOT A BUG (@MainActor guarantees serial access)
- [x] 6.3: Pipeline Task Cancellation Race — FIXED (commit 21299e5)
- [x] 7.2: Embedding Service Growth — NOT A BUG (embeddings dict fully replaced each cycle)
- [x] 8.1: FFI String Lifetime Safety — AUDITED SAFE (all 15 functions copy at boundary)
- [x] 8.2: Metal Layer Pointer Retain — NOT A BUG (Rust calls objc_retain + to_owned)
- [x] 10.1: API Key iCloud Sync Risk — FIXED (commit 8c17c42)

## Deferred (needs human or design decision)
(none yet)

## Current Session Log
| # | Wave.Item | Description | Gate | Status | Commit |
|---|-----------|-------------|------|--------|--------|
| 1 | 1.1 | Highlight flag buffer | — | ALREADY DONE | — |
| 2 | 1.2 | Physics scratch buffers | — | ALREADY DONE | — |
| 3 | 1.3 | Field line buffer | — | ALREADY DONE | — |
| 4 | 1.4 | Straight-line edges | — | ALREADY DONE | — |
| 5 | 1.5 | Motion blur removal | — | ALREADY DONE | — |
| 6 | 1.6 | List virtualization | — | ALREADY DONE | — |
| 7 | 6.1 | Graph version atomicity | — | NOT A BUG | — |
| 8 | 6.3 | Pipeline cancellation | 4/4 | FIXED | 21299e5 |
| 9 | 7.2 | Embedding growth | — | NOT A BUG | — |
| 10 | 8.1 | FFI string lifetime | — | AUDITED SAFE | — |
| 11 | 8.2 | Metal layer retain | — | NOT A BUG | — |
| 12 | 10.1 | API key iCloud sync | 4/4 | FIXED | 8c17c42 |
