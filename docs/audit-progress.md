# Audit Progress
Last updated: 2026-03-01 17:00

## Current Position
Wave: 12 | Item: 12.1 | Gate: 1 (DIAGNOSE + TEST-FIRST)

## Session Stats
Tests before: 551 (Rust) + 227 suites (Swift) | Tests after: 551 (Rust) + 227 suites (Swift) | New tests: 7
Fixes this session: 7 | Deferred: 0

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
- [x] 2.5: Diff-Based Graph Rebuild — ALREADY IMPLEMENTED (GraphBuilder.persist)
- [x] 5.2: Filename Collision Edge Case — FIXED (commit bb53d95)
- [x] 5.5: FTS5 Query Injection — FIXED (commit 8374d49)
- [x] 6.1: Graph Version Tracking — NOT A BUG (@MainActor)
- [x] 6.2: MetalGraphView Engine Handle Race — NOT A BUG (all FFI have nil guards)
- [x] 6.3: Pipeline Task Cancellation Race — FIXED (commit 21299e5)
- [x] 7.2: Embedding Service Growth — NOT A BUG (full replacement per cycle)
- [x] 8.1: FFI String Lifetime Safety — AUDITED SAFE + DOCUMENTED (commit b5e9e9a)
- [x] 8.2: Metal Layer Pointer Retain — NOT A BUG (Rust objc_retain)
- [x] 8.3: Missing Null Checks in FFI — NOT A BUG (all calls guarded)
- [x] 10.1: API Key iCloud Sync Risk — FIXED (commit 8c17c42)
- [x] 10.3: Vault Path Exposure in Logs — FIXED (commit 9b8fc96)
- [x] 11.1: Silent Failures in Graph Operations — FIXED (commit f3ba40a)
- [x] 11 (Metal Safety): Shader compilation panics — FIXED (commit b346609)

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
| 8 | 2.5 | Diff-based graph rebuild | — | ALREADY DONE | — |
| 9 | 5.2 | Filename collision | 4/4 | FIXED | bb53d95 |
| 10 | 5.5 | FTS5 query injection | 4/4 | FIXED | 8374d49 |
| 11 | 6.1 | Graph version atomicity | — | NOT A BUG | — |
| 12 | 6.2 | Engine handle race | — | NOT A BUG | — |
| 13 | 6.3 | Pipeline cancellation | 4/4 | FIXED | 21299e5 |
| 14 | 7.2 | Embedding growth | — | NOT A BUG | — |
| 15 | 8.1 | FFI string lifetime | — | AUDITED SAFE | b5e9e9a |
| 16 | 8.2 | Metal layer retain | — | NOT A BUG | — |
| 17 | 8.3 | FFI null checks | — | NOT A BUG | — |
| 18 | 10.1 | API key iCloud sync | 4/4 | FIXED | 8c17c42 |
| 19 | 10.3 | Vault path privacy | 4/4 | FIXED | 9b8fc96 |
| 20 | 11.1 | GraphBuilder silent fails | 4/4 | FIXED | f3ba40a |
| 21 | 11 | Metal shader panics | 4/4 | FIXED | b346609 |
