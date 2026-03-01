# Audit Progress
Last updated: 2026-03-01 18:30

## Current Position
Wave: 13 | Item: 13.2 | Gate: 1 (DIAGNOSE + TEST-FIRST)

## Session Stats
Tests before: 551 (Rust) + 227 suites (Swift) | Tests after: 551 (Rust) + 227 suites (Swift) | New tests: 7
Fixes this session: 12 | Deferred: 0

## Pre-Audit Fixes
- [x] Keychain Data Protection migration (commit efd2ab6) — not audit item
- [x] 11 stale Rust test assertions fixed (commit 9abb941) — not audit item
- [x] Legacy keychain migration disabled (commit a13307a) — not audit item

## Completed
- [x] 1.1: Per-Node Highlight Flag Buffer — ALREADY IMPLEMENTED
- [x] 1.2: Pre-Allocate Scratch Buffers — ALREADY IMPLEMENTED
- [x] 1.3: Pre-Allocate Field Line Buffer — ALREADY IMPLEMENTED
- [x] 1.4: Straight-Line Edges — ALREADY IMPLEMENTED
- [x] 1.5: Remove Motion Blur — ALREADY IMPLEMENTED
- [x] 1.6: List Virtualization — ALREADY IMPLEMENTED
- [x] 1.7: Search Debouncing — FIXED (commit d6204c4)
- [x] 1.9: Search Result Caching — NOT A BUG (150ms debounce + Rust FFI already mitigate)
- [x] 1.10: Frustum Culling — NOT A BUG (instanced rendering, GPU clips automatically)
- [x] 1.11: SwiftData Prefetch Relationships — FIXED (commit 3252068)
- [x] 2.5: Diff-Based Graph Rebuild — ALREADY IMPLEMENTED (GraphBuilder.persist)
- [x] 5.1: Front-Matter Parsing Edge Cases — FIXED (commit f4c223a, BOM + comments)
- [x] 5.2: Filename Collision Edge Case — FIXED (commit bb53d95)
- [x] 5.4: Empty Vault Context Crash Risk — NOT A BUG (zero callers, dead code)
- [x] 5.5: FTS5 Query Injection — FIXED (commit 8374d49)
- [x] 6.1: Graph Version Tracking — NOT A BUG (@MainActor)
- [x] 6.2: MetalGraphView Engine Handle Race — NOT A BUG (all FFI have nil guards)
- [x] 6.3: Pipeline Task Cancellation Race — FIXED (commit 21299e5)
- [x] 6.4: SwiftData Context Crossing — NOT A BUG (@MainActor isolation)
- [x] 7.2: Embedding Service Growth — NOT A BUG (full replacement per cycle)
- [x] 7.3: Note Body Memory-Mapped File Leak — NOT A BUG (mmap Data is function-scoped, String copies bytes)
- [x] 8.1: FFI String Lifetime Safety — AUDITED SAFE + DOCUMENTED (commit b5e9e9a)
- [x] 8.2: Metal Layer Pointer Retain — NOT A BUG (Rust objc_retain)
- [x] 8.3: Missing Null Checks in FFI — NOT A BUG (all calls guarded)
- [x] 9.1: Batch Delete Cascade Violation — FIXED (commit 00d064c)
- [x] 9.2: Predicates with Arrays Crashing — ALREADY IMPLEMENTED (warning comment + individual fetches)
- [x] 9.3: Transient Cache Invalidation — FIXED (commit 4ce963f)
- [x] 10.1: API Key iCloud Sync Risk — FIXED (commit 8c17c42)
- [x] 10.2: Spotlight Indexing Leaks Note Content — FIXED (commit f4c223a)
- [x] 10.3: Vault Path Exposure in Logs — FIXED (commit 9b8fc96)
- [x] 11.1: Silent Failures in Graph Operations — FIXED (commit f3ba40a)
- [x] 11 (Metal Safety): Shader compilation panics — FIXED (commit b346609)
- [x] 12.2: Dark Mode Detection Race — FIXED (commit d987851)
- [x] 13.1: Quadtree Degradation — NOT A BUG (MAX_DEPTH + distance_min clamp)
- [x] 13.3: Spotlight Reindex on Every Launch — NOT A BUG (UserDefaults persists correctly)

## Deferred (needs human or design decision)
- [ ] 1.8: Background Graph Building — Major architecture change (needs new SwiftData context)
- [ ] 1.12: Incremental FFI Graph Updates — Needs new Rust FFI functions + protocol design

## Current Session Log
| # | Wave.Item | Description | Gate | Status | Commit |
|---|-----------|-------------|------|--------|--------|
| 1 | 1.1 | Highlight flag buffer | — | ALREADY DONE | — |
| 2 | 1.2 | Physics scratch buffers | — | ALREADY DONE | — |
| 3 | 1.3 | Field line buffer | — | ALREADY DONE | — |
| 4 | 1.4 | Straight-line edges | — | ALREADY DONE | — |
| 5 | 1.5 | Motion blur removal | — | ALREADY DONE | — |
| 6 | 1.6 | List virtualization | — | ALREADY DONE | — |
| 7 | 1.7 | Search debouncing | 3/4 | FIXED | d6204c4 |
| 8 | 1.9 | Search result caching | — | NOT A BUG | — |
| 9 | 1.10 | Frustum culling | — | NOT A BUG | — |
| 10 | 1.11 | Prefetch relationships | 4/4 | FIXED | 3252068 |
| 11 | 2.5 | Diff-based graph rebuild | — | ALREADY DONE | — |
| 12 | 5.1 | Front-matter parsing | 4/4 | FIXED | f4c223a |
| 13 | 5.2 | Filename collision | 4/4 | FIXED | bb53d95 |
| 14 | 5.4 | Empty vault context | — | NOT A BUG | — |
| 15 | 5.5 | FTS5 query injection | 4/4 | FIXED | 8374d49 |
| 16 | 6.1 | Graph version atomicity | — | NOT A BUG | — |
| 17 | 6.2 | Engine handle race | — | NOT A BUG | — |
| 18 | 6.3 | Pipeline cancellation | 4/4 | FIXED | 21299e5 |
| 19 | 6.4 | SwiftData context crossing | — | NOT A BUG | — |
| 20 | 7.2 | Embedding growth | — | NOT A BUG | — |
| 21 | 7.3 | Mmap file leak | — | NOT A BUG | — |
| 22 | 8.1 | FFI string lifetime | — | AUDITED SAFE | b5e9e9a |
| 23 | 8.2 | Metal layer retain | — | NOT A BUG | — |
| 24 | 8.3 | FFI null checks | — | NOT A BUG | — |
| 25 | 9.1 | Batch delete cascade | 4/4 | FIXED | 00d064c |
| 26 | 9.2 | Predicates with arrays | — | ALREADY DONE | — |
| 27 | 9.3 | Transient cache | 4/4 | FIXED | 4ce963f |
| 28 | 10.1 | API key iCloud sync | 4/4 | FIXED | 8c17c42 |
| 29 | 10.2 | Spotlight body exposure | 4/4 | FIXED | f4c223a |
| 30 | 10.3 | Vault path privacy | 4/4 | FIXED | 9b8fc96 |
| 31 | 11.1 | GraphBuilder silent fails | 4/4 | FIXED | f3ba40a |
| 32 | 11 | Metal shader panics | 4/4 | FIXED | b346609 |
| 33 | 12.2 | Dark mode detection | 4/4 | FIXED | d987851 |
| 34 | 13.1 | Quadtree degradation | — | NOT A BUG | — |
| 35 | 13.3 | Spotlight reindex | — | NOT A BUG | — |
